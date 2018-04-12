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
    
}

enum FilterStore: Int {
    case grayscale
    case divide
    case hilo
    
    static var allCases: [FilterStore] { return [.grayscale, .divide, .hilo] }
}

class ViewController: NSViewController {
    
    let analyser = ImageAnalyser.sharedInstance
    
    @IBOutlet weak var filterSelection: NSPopUpButton!
    @IBOutlet weak var firstInputImageView: NSImageView!
    @IBOutlet weak var secondInputImageView: NSImageView!
    @IBOutlet weak var processedImageView: NSImageView!
    @IBOutlet weak var processedImageLineProfileView: LineProfileView!
    
    @IBOutlet weak var drawLineOnImageViewBtn: NSButton!
    
    
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
    var processedImage = Variable<NSImage?>(nil)
    
    var currentFilter: FilterStore = .hilo
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupFilterSelectionPopUp()
        setupDrawLineProfile()
        
        bindImages()
        assignImage()
        
        setupHiloParametersSlidersAndLabels()
        
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
        
        
        
        let lineRect = NSRect(x: 0, y: processedImageView.bounds.height*0.5, width: processedImageView.bounds.width, height: 2)
        let line = Line(frame: lineRect)
        self.processedImageView.addSubview(line)
        
        drawLineOnImageViewBtn.rx.state
            .map { $0 == NSControl.StateValue.off }
            .bind(to: line.rx.isHidden)
            .disposed(by: disposeBag)
        
        drawLineOnImageViewBtn.rx.state
            .map { $0 == NSControl.StateValue.off }
            .bind(to: processedImageLineProfileView.rx.isHidden)
            .disposed(by: disposeBag)
    }
    
    fileprivate func bindImages() {
        inputImage1.asObservable().bind(to: firstInputImageView.rx.image).disposed(by: disposeBag)
        inputImage2.asObservable().bind(to: secondInputImageView.rx.image).disposed(by: disposeBag)
        processedImage.asObservable().bind(to: processedImageView.rx.image).disposed(by: disposeBag)
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
            
            self?.processHilo()
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
    
    private func assignImage() {
        
        processedImage.value = nil
        
        switch currentFilter {
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

    @IBAction func selectFilter(_ sender: NSPopUpButton) {
        
        currentFilter = FilterStore(rawValue: filterSelection.indexOfSelectedItem) ?? .grayscale
        
        assignImage()
        
        processCurrentFilter()
        
    }
    
    func processCurrentFilter() {
        debugPrint("Processing Image with \(currentFilter)")
        switch currentFilter {
        case .grayscale:
            processGrayscale()
        case .divide:
            processDivide()
        case .hilo:
            processHilo()
        }
    }
    
    private func processGrayscale() {
        processedImage.value = imageFrom(bitmap: analyser.computeGrayscaleFrom(bitmap: bitmapFrom(image: inputImage1.value)))
    }
    
    private func processDivide() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value) else { return }
        
        let newBitmap = analyser.metalDivide(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle, normalize: true)
        processedImage.value = imageFrom(bitmap: newBitmap)
    }
    
    private func processHilo() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value)
            else { return }
        
        guard let bitmapHiLo = analyser.hiloFrom(bitmapUniform: bitmapUniform, bitmapSpeckle: bitmapSpeckle, parameters: hiloParameters)
            else { return }
        
        let imageView = NSImageView(image: imageFrom(bitmap: bitmapHiLo)!)
        self.view.addSubview(imageView)
        processedImage.value = imageFrom(bitmap: bitmapHiLo)
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
        plotLineProfile(relativeLocation: getMouseRelativeLocationInImageView(event))
    }
    
    override func mouseDown(with event: NSEvent) {
        plotLineProfile(relativeLocation: getMouseRelativeLocationInImageView(event))
    }

    fileprivate func getMouseRelativeLocationInImageView(_ event: NSEvent) -> CGFloat {
        let locationInWindow = event.locationInWindow
        let locationInImageView = processedImageView.convert(locationInWindow, from: self.view)
        
        
        var relativeLocation = locationInImageView.y/processedImageView.bounds.height
        
        relativeLocation = relativeLocation < 0 ? 0 : relativeLocation
        relativeLocation = relativeLocation > 1 ? 1 : relativeLocation
        
        return relativeLocation
    }
    
    fileprivate func drawLineAt(relativeLocation: CGFloat) {
        for sv in processedImageView.subviews where sv is Line {
            let lineRect = NSRect(x: 0, y: processedImageView.bounds.height*relativeLocation, width: processedImageView.bounds.width, height: 2)
            sv.frame = lineRect
        }
    }
    
    fileprivate func plotLineProfile(relativeLocation: CGFloat) {
        if drawLineOnImageViewBtn.state == NSControl.StateValue.on {
            drawLineAt(relativeLocation: relativeLocation)
            
            guard let data = analyser.lineDataFrom(bitmap: bitmapFrom(image: processedImage.value), atRelativeHeight: Double(relativeLocation)) else { return }
            processedImageLineProfileView.setDataPoints(dataPoints: data)
        }
    }
}

class Line: NSView {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: dirtyRect.width, y: 0))
        context.setStrokeColor(.init(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(2.0)
        context.strokePath()
    }
}

class LineProfileView: NSView {
    
    var dataPoints: [CGFloat] = []
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.beginPath()
        dataPoints.isEmpty ? context.move(to: CGPoint(x: 0, y: 0)) : context.move(to: CGPoint(x: 0, y: dataPoints[0]))
//        context.move(to: CGPoint(x: 0, y: 0))
        for (position, point) in dataPoints.enumerated() {
            context.addLine(to: CGPoint(x: CGFloat(position), y: point))
        }
        context.setStrokeColor(.init(red: 1, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(2.0)
        context.strokePath()
    }
    
    func setDataPoints(dataPoints: [UInt8]) {
        debugPrint(dataPoints[0...10])
        self.dataPoints = normalize(data: dataPoints)
        debugPrint(self.dataPoints[0...10])
        self.display()
    }
    
    func normalize(data: [UInt8]) -> [CGFloat] {
        let height = self.bounds.height
        let maxValue = CGFloat( data.max() ?? 1 )
        return data.map {height*CGFloat($0)/maxValue}
    }
    
    
}

