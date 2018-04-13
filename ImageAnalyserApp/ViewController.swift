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
    static let imageForGrayscale = NSImage.Name("image-3")
    static let scr1 = NSImage.Name("scr1")
    static let scr2 = NSImage.Name("scr2")
    static let imageSpeckle = NSImage.Name("ImageSpeckle")
    static let imageUniform = NSImage.Name("ImageUniform")
    static let imageHilo = NSImage.Name("ImageHilo.png")
    static let circularGradient = NSImage.Name("CircularGradient")
}

enum FilterStore: Int {
    case nothing
    case grayscale
    case divide
    case hilo
    
    static var allCases: [FilterStore] { return [.nothing, .grayscale, .divide, .hilo] }
}

class ViewController: NSViewController {
    
    let analyser = ImageAnalyser.sharedInstance
    
    @IBOutlet weak var filterSelection: NSPopUpButton!
    
    @IBOutlet weak var inputImage1View: NSImageView!
    @IBOutlet weak var inputImage2View: NSImageView!
    @IBOutlet weak var outImageView: NSImageView!
    
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
    
    var inputImage1 = Variable<NSImage?>(nil)
    var inputImage2 = Variable<NSImage?>(nil)
    var outImage = Variable<NSImage?>(nil)
    
    var isInputImage2Hidden = Variable<Bool>(false)
    
    var currentFilter: FilterStore = .hilo
    
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
        filterSelection.selectItem(at: currentFilter.hashValue)
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
            inputImage1.value = NSImage(named: NSImage.Name.imageUniform)
            inputImage2.value = NSImage(named: NSImage.Name.imageSpeckle)
        }
    }

    fileprivate func setupHiloParametersSlidersAndLabels() {
        self.setup(slider: targetThicknessSlider, initialValue: hiloParameters.targetThickness)
        self.setup(slider: waveletGaussiansRatioSlider, initialValue: hiloParameters.waveletGaussiansRatio)
        self.setup(slider: etaSlider, initialValue: hiloParameters.eta,maxValue: 50.0)
        
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
        
        Observable.combineLatest(targetThicknessSlider.rx.value.asObservable(), waveletGaussiansRatioSlider.rx.value.asObservable(), etaSlider.rx.value.asObservable()) { [weak self] targetThickness, waveletGaussiansRatio, eta in
            
            self?.hiloParameters = HiLoParameters(targetThickness: targetThickness, eta: eta, waveletGaussiansRatio: waveletGaussiansRatio)
            
            self?.processCurrentFilter()
            }
            .debounce(0.1, scheduler: MainScheduler.instance)
            .subscribe()
            .disposed(by: disposeBag)
        
    }
    
    fileprivate func setup(slider: NSSlider, initialValue: Double, maxValue: Double = 20.0) {
        slider.doubleValue = initialValue
        slider.maxValue = maxValue
        slider.minValue = 0.01
        slider.altIncrementValue = 0.05
    }
    
    private func stringFromNumber(number: Double) -> String {
        return String(format: "%0.2f", number)
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
        }
        
        plotImageProfile()
    }
    
    fileprivate func processNothing() {
        outImage.value = inputImage1.value
    }
    
    private func processGrayscale() {
        outImage.value = imageFrom(bitmap: analyser.computeGrayscaleFrom(bitmap: bitmapFrom(image: inputImage1.value)))
    }
    
    private func processDivide() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value) else { return }
        
        let newBitmap = analyser.metalDivide(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle, normalize: true)
        outImage.value = imageFrom(bitmap: newBitmap)
    }
    
    private func processHilo() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value)
            else { return }
        
        guard let bitmapHiLo = analyser.hiloFrom(bitmapUniform: bitmapUniform, bitmapSpeckle: bitmapSpeckle, parameters: hiloParameters)
            else { return }
        
        let imageView = NSImageView(image: imageFrom(bitmap: bitmapHiLo)!)
        self.view.addSubview(imageView)
        outImage.value = imageFrom(bitmap: bitmapHiLo)
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
        if drawLineOnImageViewBtn.state == NSControl.StateValue.on {
            guard let inputImage1LineData = analyser.lineDataFrom(bitmap: bitmapFrom(image: inputImage1.value), atRelativeHeight: Double(self.lineProfileRelativeLocation)),
                let outImageLineData = analyser.lineDataFrom(bitmap: bitmapFrom(image: outImage.value), atRelativeHeight: Double(self.lineProfileRelativeLocation)) else { return }
            imageLineProfileView.setDataPoints(dataPoints: [inputImage1LineData, outImageLineData])
        }
    }
    
}

class DrawView: NSView {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    func drawLine(points: [CGPoint], color: CGColor) {
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
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
    
    func setDataPoints(dataPoints: [[UInt8]]) {
        self.allData = normalizeDataToFitInBounds(data: dataPoints)
        self.display()
    }
    
    func normalizeDataToFitInBounds(data: [[UInt8]]) -> [[(x: CGFloat, y: CGFloat)]] {
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

