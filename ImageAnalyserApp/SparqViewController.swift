//
//  ViewController.swift
//  ImageAnalyserApp
//
//  Created by Steve Begin on 2018-03-22.
//  Copyright © 2018 BLIQc. All rights reserved.
//

import Cocoa
import ImageAnalyser
import RxSwift
import RxCocoa

extension NSImage.Name {
    static let imageForGrayscale = "image-4"
    static let scr1 = "scr1"
    static let scr2 = "scr2"
    static let imageSpeckle = "ImageSpeckle"
    static let imageUniform = "ImageUniform"
    static let imageHilo = "ImageHilo.png"
    static let circularGradient = "CircularGradient"
}

enum FilterStore: Int {
    case nothing
    case grayscale
    case divide
    case hilo
    case slam
    
    static var allCases: [FilterStore] { return [.nothing, .grayscale, .divide, .hilo, .slam] }
}

class SparqViewController: NSViewController {
    
    let analyser: ImageAnalyser = (try? MetalImageAnalyser.sharedInstance) ?? FakeImageAnalyser.sharedInstance()
    
    @IBOutlet weak var filterSelection: NSPopUpButton!
    
    @IBOutlet weak var inputImage1View: NSImageView!
    @IBOutlet weak var inputImage2View: NSImageView!
    @IBOutlet weak var outImageView: NSImageView!
   
    @IBOutlet weak var drawView: DrawView!
    
    @IBOutlet weak var imageLineProfileView: LineProfileView!
    @IBOutlet weak var drawLineOnImageViewBtn: NSButton!
    
    var lineProfileRelativeLocation: CGFloat = 0
    
    //HiLo parameters
    var hiloParameters = HiLoParameters()
    
    @IBOutlet weak var targetThicknessSlider: NSSlider!
    @IBOutlet weak var targetThicknessLbl: NSTextField!
    @IBOutlet weak var waveletGaussiansRatioSlider: NSSlider!
    @IBOutlet weak var waveletGaussiansRatioLbl: NSTextField!
    @IBOutlet weak var etaSlider: NSSlider!
    @IBOutlet weak var etaLbl: NSTextField!
    
    
    @IBOutlet weak var shotNoiseCorrectionBtn: NSButton!
    @IBOutlet weak var filterVolumeSlider: NSSlider!
    @IBOutlet weak var filterVolumeLbl: NSTextField!
    @IBOutlet weak var cameraGainSlider: NSSlider!
    @IBOutlet weak var cameraGainLbl: NSTextField!
    @IBOutlet weak var readoutNoiseSlider: NSSlider!
    @IBOutlet weak var readoutNoiseLbl: NSTextField!
    
    //Load images
    private var loadedUniformImage: NSImage?
    private var loadedSpeckleImage: NSImage?
    
    
    @IBOutlet weak var loadUniformImageBtn: NSButton!
    @IBOutlet weak var uniformImageUrlLbl: NSTextField!
    @IBOutlet weak var loadSpeckleImageBtn: NSButton!
    @IBOutlet weak var speckleImageUrlLbl: NSTextField!
    @IBOutlet weak var useDefaultImagesBtn: NSButton!
    @IBAction func useDefaultImagesBtnACTION(_ sender: NSButton) {
        loadedUniformImage = nil
        loadSpeckleImageBtn = nil
        
        assignInputImages()
        
        processCurrentFilter()
    }
    
    @IBAction func loadUniformImageBtnACTION(_ sender: NSButton) {
        guard let url = loadImageUrl() else { return }
        
        loadedUniformImage = NSImage(byReferencing: url)
        
        assignInputImages()
        
        processCurrentFilter()
    }
    
    @IBAction func loadSpeckleImageBtnACTION(_ sender: NSButton) {
        guard let url = loadImageUrl() else { return }
        
        loadedSpeckleImage = NSImage(byReferencing: url)
        
        assignInputImages()
        
        processCurrentFilter()
    }
    
    private func loadImageUrl() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["tiff", "tif", "png"]
        
        if panel.runModal() == NSApplication.ModalResponse.OK {
            return panel.urls.first
        }
        return nil
    }
    
    var inputImage1 = Variable<NSImage?>(nil)
    var inputImage2 = Variable<NSImage?>(nil)
    var outImage = Variable<NSImage?>(nil)
    
    var isInputImage2Hidden = Variable<Bool>(false)
    
    var currentFilter: FilterStore = .nothing
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupFilterSelectionPopUp()
        
        bindImagesToImageViews()
        assignInputImages()
        
        setupHiloParametersSlidersAndLabels()
        
    }
    
    override func viewDidAppear() {
        setupDrawLineProfile()
        processCurrentFilter()

    }
    
    fileprivate func setupFilterSelectionPopUp() {
        filterSelection.removeAllItems()
        for filter in FilterStore.allCases {
            filterSelection.addItem(withTitle: "\(filter)")
        }
        filterSelection.selectItem(at: currentFilter.rawValue)
    }
    
    fileprivate func setupDrawLineProfile() {

        
        //let inputImage1ViewlineProfile = DrawView(frame: inputImage1View.bounds)
        let inputImage1ViewlineProfile = Line(frame: NSRect(x: 0, y: inputImage1View.bounds.height*0.5, width: inputImage1View.bounds.width, height: 2))
        self.inputImage1View.addSubview(inputImage1ViewlineProfile)

        //let outImageViewlineProfile = DrawView(frame: outImageView.bounds)
        let outImageViewlineProfile = Line(frame: NSRect(x: 0, y: outImageView.bounds.height*0.5, width: outImageView.bounds.width, height: 2))
        self.outImageView.addSubview(outImageViewlineProfile)
        
        drawLineOnImageViewBtn.rx.state
            .map { $0 == NSControl.StateValue.off }
            .bind(to: inputImage1ViewlineProfile.rx.isHidden)
            .disposed(by: disposeBag)
        
        drawLineOnImageViewBtn.rx.state
            .map { $0 == NSControl.StateValue.off }
            .bind(to: outImageViewlineProfile.rx.isHidden)
            .disposed(by: disposeBag)
        
        drawLineOnImageViewBtn.rx.state
            .map { $0 == NSControl.StateValue.off }
            .bind(to: imageLineProfileView.rx.isHidden)
            .disposed(by: disposeBag)
    }
    
    fileprivate func bindImagesToImageViews() {
        inputImage1.asObservable().bind(to: inputImage1View.rx.image).disposed(by: disposeBag)
        inputImage2.asObservable().bind(to: inputImage2View.rx.image).disposed(by: disposeBag)
        outImage.asObservable().bind(to: outImageView.rx.image).disposed(by: disposeBag)
        
        isInputImage2Hidden.asObservable()
        .bind(to: inputImage2View.rx.isHidden)
        .disposed(by: disposeBag)
    }
    
    private func assignInputImages() {
        outImage.value = nil
        switch currentFilter {
        case .nothing:
            inputImage1.value = NSImage(named: NSImage.Name.circularGradient)
            inputImage2.value = nil
        case .grayscale:
            inputImage1.value = NSImage(named: NSImage.Name.imageForGrayscale)
            inputImage2.value = nil
        case .divide:
            inputImage1.value = NSImage(named: NSImage.Name.scr1)
            inputImage2.value = NSImage(named: NSImage.Name.scr2)
        case .hilo:
            if let uniform = loadedUniformImage, let speckle = loadedSpeckleImage {
                inputImage1.value = uniform
                inputImage2.value = speckle
            } else {
                inputImage1.value = NSImage(named: NSImage.Name.imageUniform)
                inputImage2.value = NSImage(named: NSImage.Name.imageSpeckle)
            }
        case .slam:
            inputImage1.value = NSImage(named: NSImage.Name.scr1)
            inputImage2.value = NSImage(named: NSImage.Name.scr2)
        }
    }

    fileprivate func setupHiloParametersSlidersAndLabels() {
        self.setup(slider: targetThicknessSlider, initialValue: hiloParameters.targetThickness, maxValue: 20.0)
        self.setup(slider: waveletGaussiansRatioSlider, initialValue: hiloParameters.waveletGaussiansRatio, maxValue: 20.0)
        self.setup(slider: etaSlider, initialValue: hiloParameters.eta, maxValue: 20.0)
        self.setup(slider: filterVolumeSlider, initialValue: hiloParameters.bandPassFilterVolume, maxValue: 0.01, minValue: 0.0001)
        self.setup(slider: cameraGainSlider, initialValue: hiloParameters.cameraGain, maxValue: 0.01, minValue: 0.0001)
        self.setup(slider: readoutNoiseSlider, initialValue: hiloParameters.readoutNoise, maxValue: 0.01, minValue: 0.0001)
        
        targetThicknessSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.targetThicknessLbl.rx.text)
            .disposed(by: disposeBag)
        
        waveletGaussiansRatioSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.waveletGaussiansRatioLbl.rx.text)
            .disposed(by: disposeBag)
        
        etaSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.etaLbl.rx.text)
            .disposed(by: disposeBag)
        
        filterVolumeSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0, significantPlaces: 4) }
            .bind(to: self.filterVolumeLbl.rx.text)
            .disposed(by: disposeBag)
        
        cameraGainSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0, significantPlaces: 4) }
            .bind(to: self.cameraGainLbl.rx.text)
            .disposed(by: disposeBag)
        
        readoutNoiseSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0, significantPlaces: 4) }
            .bind(to: self.readoutNoiseLbl.rx.text)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(targetThicknessSlider.rx.value.asObservable(),
                                 waveletGaussiansRatioSlider.rx.value.asObservable(),
                                 etaSlider.rx.value.asObservable(),
                                 shotNoiseCorrectionBtn.rx.state.asObservable(),
                                 filterVolumeSlider.rx.value.asObservable(),
                                 cameraGainSlider.rx.value.asObservable(),
                                 readoutNoiseSlider.rx.value.asObservable()) { [weak self] targetThickness, waveletGaussiansRatio, eta, doShotNoiseCorrection, filterVolume, cameraGain, readoutNoise in
            
            self?.hiloParameters = HiLoParameters(targetThickness: targetThickness, eta: eta, waveletGaussiansRatio: waveletGaussiansRatio, doShotNoiseCorrection: doShotNoiseCorrection == .on, bandPassFilterVolume: filterVolume, cameraGain: cameraGain, readoutNoise: readoutNoise)
            
            self?.processCurrentFilter()
            }
//            .debounce(0.1, scheduler: MainScheduler.instance)
            .subscribe()
            .disposed(by: disposeBag)
        
    }
    
    fileprivate func setup(slider: NSSlider, initialValue: Double, maxValue: Double = 20.0, minValue: Double = 0.01) {
        slider.doubleValue = initialValue
        slider.maxValue = maxValue
        slider.minValue = minValue
        slider.altIncrementValue = 0.05
    }
    
    private func stringFromNumber(number: Double, significantPlaces: Int = 2) -> String {
        return String(format: "%0.\(significantPlaces)f", number)
    }
    
    
    @IBAction func selectFilter(_ sender: NSPopUpButton) {
        
        currentFilter = FilterStore(rawValue: filterSelection.indexOfSelectedItem) ?? .grayscale
        
        assignInputImages()
        
        processCurrentFilter()
        
    }
    
    func processCurrentFilter() {
        debugPrint("Processing Image with \(currentFilter)")
        switch currentFilter {
        case .nothing:
            isInputImage2Hidden.value = true
            processNothing()
        case .grayscale:
            isInputImage2Hidden.value = true
            processGrayscale()
        case .divide:
            isInputImage2Hidden.value = false
            processDivide()
        case .hilo:
            isInputImage2Hidden.value = true
            processHilo()
        case .slam:
            isInputImage2Hidden.value = false
            processSlam()
        }
        
        plotImageProfile()
    }
    
    fileprivate func processNothing() {
        outImage.value = inputImage1.value
    }
    
    private func processGrayscale() {
        
        guard let bitmap = bitmapFrom(image: inputImage1.value) else {
            return
        }
        do {
            let outBitmap = try analyser.computeGrayscaleOf(bitmap: bitmap, channel: .rgb)
            outImage.value = imageFrom(bitmap: outBitmap)
        } catch {
            presentError(error)
        }
        
    }
    
    private func processDivide() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value) else { return }
        
        let newBitmap = try? analyser.computeDivide(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle)
        outImage.value = imageFrom(bitmap: newBitmap)
    }
    
    private func processHilo() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value)
            else { return }
        
        guard let bitmapHiLo = try? analyser.computeSparqFrom(bitmapUniform: bitmapUniform, bitmapSpeckle: bitmapSpeckle, parameters: hiloParameters)
            else { return }
        
        let imageView = NSImageView(image: imageFrom(bitmap: bitmapHiLo)!)
        self.view.addSubview(imageView)
        outImage.value = imageFrom(bitmap: bitmapHiLo)
        self.imageLineProfileView.display()
    }
    
    private func processSlam() {
        guard let bitmapBright = bitmapFrom(image: inputImage1.value), let bitmapDark = bitmapFrom(image: inputImage2.value)
            else { return }
        
        guard let bitmapSlam = try? analyser.computeSlamFrom(bitmapBright: bitmapBright, bitmapDark: bitmapDark, parameters: SlamParameters(g: 1) )
            else { return }
        
        let imageView = NSImageView(image: imageFrom(bitmap: bitmapSlam)!)
        self.view.addSubview(imageView)
        outImage.value = imageFrom(bitmap: bitmapSlam)
        self.imageLineProfileView.display()
    }
    
    private func bitmapFrom(image: NSImage?) -> NSBitmapImageRep? {
        guard let data = image?.tiffRepresentation else {
            debugPrint("No Image to process")
            return nil
        }
        return NSBitmapImageRep(data: data)
    }
    
    private func imageFrom(bitmap: NSBitmapImageRep? ) -> NSImage? {
        guard let bitmap = bitmap, let cgImage = bitmap.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: bitmap.size)
    }
    
    override func mouseDragged(with event: NSEvent) {
        plotLineProfileAt(location: event.locationInWindow)
        plotImageProfile()
    }
    
    override func mouseDown(with event: NSEvent) {
        plotLineProfileAt(location: event.locationInWindow)
        plotImageProfile()
    }

    fileprivate func lineProfileRelativeLocationInImageViewFrom(mouseLocationInWindow: NSPoint) -> CGFloat {
        
        let locationInImageView = outImageView.convert(mouseLocationInWindow, from: self.view)
        
        var relativeLocation = locationInImageView.y/outImageView.bounds.height
        
        relativeLocation = relativeLocation < 0 ? 0 : relativeLocation
        relativeLocation = relativeLocation > 1 ? 1 : relativeLocation
        
        return relativeLocation
    }
    
    fileprivate func plotLineProfileAt(location: NSPoint) {
        
        let points = [CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5) ]
        drawView.drawLine(points: points, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        
        if drawLineOnImageViewBtn.state == NSControl.StateValue.on {
            self.lineProfileRelativeLocation = lineProfileRelativeLocationInImageViewFrom(mouseLocationInWindow:location)
            drawLineAt(relativeLocation: self.lineProfileRelativeLocation)
        }
    }
    
    fileprivate func drawLineAt(relativeLocation: CGFloat) {
        
        for (n, imageView) in [outImageView, inputImage1View].enumerated() {
            guard let imageView = imageView else { return }
            
            let points = [CGPoint(x: 0, y: imageView.bounds.height*relativeLocation),
                          CGPoint(x: imageView.bounds.width, y: imageView.bounds.height*relativeLocation)]
            
            for sv in imageView.subviews where sv is Line {
                let lineRect = NSRect(x: 0, y: outImageView.bounds.height*relativeLocation, width: outImageView.bounds.width, height: 2)
                sv.frame = lineRect
            }
            
            for sv in imageView.subviews where sv is DrawView {
                let drawView = sv as! DrawView
                drawView.drawLine(points: points, color: CGColor(red: 1, green: 0, blue: 0, alpha: 1) )
            }
        }
    }
    
    fileprivate func plotImageProfile() {

        return
        if drawLineOnImageViewBtn.state == NSControl.StateValue.on {
            
            
            guard let bitmap1 = bitmapFrom(image: inputImage1.value),
                let inputImage1LineData = try? analyser.computeLineDataFrom(bitmap: bitmap1, atRelativeHeight: Double(self.lineProfileRelativeLocation)),
                let bitmap2 = bitmapFrom(image: outImage.value),
                let outImageLineData = try? analyser.computeLineDataFrom(bitmap: bitmap2, atRelativeHeight: Double(self.lineProfileRelativeLocation)) else { return }
            //imageLineProfileView.setDataPoints(dataPoints: [inputImage1LineData, outImageLineData])
        }
    }
    
}

class DrawView: NSView {
    
    var context: CGContext?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
//        self.wantsLayer = true
//        self.layer?.backgroundColor = CGColor(gray: 0.5, alpha: 1)
//
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        self.context = context
    }
    
    func drawLine(points: [CGPoint], color: CGColor) {
        
        guard let context = self.context else { return }
        
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        
        for point in normalizeDataPointsToFitInBounds(points: points) {
            context.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        
        context.setStrokeColor(color)
        context.setLineWidth(1.0)
        context.strokePath()
        
    }
    
    fileprivate func normalizeDataPointsToFitInBounds(points: [CGPoint]) -> [CGPoint] {
        let height = self.bounds.height
        let width = self.bounds.width
        
        var normalisedPoints: [CGPoint] = []
        
        var yMaxValue =  points.map({$0.y}).max() ?? 1
        yMaxValue = yMaxValue == 0 ? 1: yMaxValue
        let xMaxValue = CGFloat(points.count)
        
        for point in points {
            let y = point.y*height/yMaxValue
            let x = point.x*width/xMaxValue
            let newPoint = CGPoint(x: x, y: y)
            normalisedPoints.append(newPoint)
        }
        return normalisedPoints
    }
}

class Line: NSView {
    
    var context: CGContext?
    fileprivate let colors: [CGColor] = [.init(red: 1, green: 0, blue: 0, alpha: 1),
                                         .init(red: 0, green: 1, blue: 0, alpha: 1),
                                         .init(red: 0, green: 0, blue: 1, alpha: 1),
                                         .init(red: 1, green: 1, blue: 0, alpha: 1),
                                         .init(red: 1, green: 0, blue: 1, alpha: 1),
                                         .init(red: 0, green: 1, blue: 1, alpha: 1)]
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        self.context = context
        
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: dirtyRect.width, y: 0))
        context.setStrokeColor(.init(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(2.0)
        context.strokePath()
    }
}

class LineProfileView: NSView {
    
    var allData: [[(x: CGFloat, y: CGFloat)]] = []
    
    fileprivate let colors: [CGColor] = [.init(red: 1, green: 0, blue: 0, alpha: 1),
                                         .init(red: 0, green: 1, blue: 0, alpha: 1),
                                         .init(red: 0, green: 0, blue: 1, alpha: 1),
                                         .init(red: 1, green: 1, blue: 0, alpha: 1),
                                         .init(red: 1, green: 0, blue: 1, alpha: 1),
                                         .init(red: 0, green: 1, blue: 1, alpha: 1)]
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext,
            !allData.isEmpty
            else { return }
        for (n, data) in allData.enumerated() {
            context.beginPath()
            context.move(to: CGPoint(x: data[0].x, y: data[0].y))
            for point in data {
                context.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            context.setStrokeColor(colors[n%colors.count])
            context.setLineWidth(1.0)
            context.strokePath()
        }
    }
    
    func setDataPoints(dataPoints: [[Int]]) {
        self.allData = normalizeDataToFitInBounds(data: dataPoints)
        self.display()
    }
    
    func normalizeDataToFitInBounds(data: [[Int]]) -> [[(x: CGFloat, y: CGFloat)]] {
        let height = self.bounds.height
        let width = self.bounds.width
        var normalisedData: [[(x: CGFloat, y: CGFloat)]] = []
        
        var yMaxValue = CGFloat(data.map({$0.max() ?? 1}).max() ?? 1 )
        yMaxValue = yMaxValue == 0 ? 1: yMaxValue
        
        for data in data {
            
            let xMaxValue = CGFloat(data.count)
            
            var points: [(x: CGFloat, y: CGFloat)] = []
            for (idx, element) in data.enumerated() {
                let y = CGFloat(element)*height/yMaxValue
                let x = CGFloat(idx)*width/xMaxValue
                points.append((x, y))
            }
            normalisedData.append(points)
        }
        return normalisedData
    }
    
    
}

