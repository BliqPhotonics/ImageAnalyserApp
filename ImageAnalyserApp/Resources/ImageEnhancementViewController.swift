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

class ImageEnhancementViewController: NSViewController {
    
    let analyser = MetalImageAnalyser.sharedInstance
    
    @IBOutlet weak var inputImage1View: NSImageView!
    @IBOutlet weak var outImageView: NSImageView!
    
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var brightnessValueLbl: NSTextField!
    @IBOutlet weak var scalingSlider: NSSlider!
    @IBOutlet weak var scalingValueLbl: NSTextField!
    @IBOutlet weak var contrastSlider: NSSlider!
    @IBOutlet weak var contrastValueLbl: NSTextField!
    
    var doHistEq: Bool = false
    @IBAction func histogramEqualizationBtnACTION(_ sender: Any) {
        processHistogramEq()
    }
    
    @IBAction func resetBtnACTION(_ sender: Any) {
        setupSlidersAndLabels()
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
    var outImage = Variable<NSImage?>(nil)
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindImagesToImageViews()
        assignInputImages()
        
        setupSlidersAndLabels()
        
    }
    
    override func viewDidAppear() {
        processCurrentFilter()
    }
    
    fileprivate func bindImagesToImageViews() {
        inputImage1.asObservable().bind(to: inputImage1View.rx.image).disposed(by: disposeBag)
        outImage.asObservable().bind(to: outImageView.rx.image).disposed(by: disposeBag)
    }
    
    private func assignInputImages() {
        
        guard let image = NSImage(named: NSImage.Name.imageForGrayscale) else { return }
        let ratio = image.size.width/image.size.height
        let w = 200
        let h = Int(round(CGFloat(w)/ratio))
        inputImage1.value = resize(image: image, w: w, h: h)
        
        outImage.value = nil
    }

    func resize(image: NSImage, w: Int, h: Int) -> NSImage {
        let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        
        let initialRec = NSMakeRect(0, 0, image.size.width, image.size.height)
        let destRec = NSMakeRect(0, 0, destSize.width, destSize.height)
        
        image.draw(in: destRec, from: initialRec, operation: .sourceOver, fraction: 1.0)
        
        newImage.unlockFocus()
        newImage.size = destSize
        return NSImage(data: newImage.tiffRepresentation!)!
    }
    
    fileprivate func setupSlidersAndLabels() {
        self.setup(slider: brightnessSlider, initialValue: 0, maxValue: 255, minValue: -255, altIncrementValue: 1)
        self.setup(slider: scalingSlider, initialValue: 1, maxValue: 10, minValue: 0.1, altIncrementValue: 0.1)
        self.setup(slider: contrastSlider, initialValue: 1, maxValue: 2, minValue: 0, altIncrementValue: 0.01)
        
        brightnessSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.brightnessValueLbl.rx.text)
            .disposed(by: disposeBag)
        
        scalingSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.scalingValueLbl.rx.text)
            .disposed(by: disposeBag)
        
        contrastSlider.rx.value
            .distinctUntilChanged()
            .map { self.stringFromNumber(number: $0) }
            .bind(to: self.contrastValueLbl.rx.text)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(brightnessSlider.rx.value.asObservable(),
                                 scalingSlider.rx.value.asObservable(),
                                 contrastSlider.rx.value.asObservable()) { [weak self] brightness, scaling, contrast in
            
            self?.processCurrentFilter()
            }
//            .debounce(0.1, scheduler: MainScheduler.instance)
            .subscribe()
            .disposed(by: disposeBag)
        
    }
    
    fileprivate func setup(slider: NSSlider, initialValue: Double, maxValue: Double = 20.0, minValue: Double = 0.01, altIncrementValue: Double = 0.05) {
        slider.doubleValue = initialValue
        slider.maxValue = maxValue
        slider.minValue = minValue
        slider.altIncrementValue = altIncrementValue
    }
    
    private func stringFromNumber(number: Double, significantPlaces: Int = 2) -> String {
        return String(format: "%0.\(significantPlaces)f", number)
    }
  
    func processCurrentFilter() {
        guard let bitmap = bitmapFrom(image: inputImage1.value) else {
            return
        }
        do {
            let tex = try analyser.createTextureFrom(bitmap: bitmap)
            
            let value = brightnessSlider.floatValue/255.0
            let out1 = try analyser.computeChangeBrightnessOf(texture: tex, byValues: [value])
            let out2 = try analyser.computeScale(texture: out1, byFactors: [scalingSlider.floatValue, scalingSlider.floatValue, scalingSlider.floatValue])
            let out3 = try analyser.computeChangeContrastOf(texture: out2, byFactors: [contrastSlider.floatValue, contrastSlider.floatValue, contrastSlider.floatValue])
            
            let outBitmap = try analyser.createBitmapFrom(texture: out3, bitsPerSample: bitmap.bitsPerSample, samplesPerPixel: bitmap.samplesPerPixel)
            outImage.value = imageFrom(bitmap: outBitmap)
        } catch {
            presentError(error)
        }
    }
    
    func processHistogramEq() {
        guard let bitmap = bitmapFrom(image: inputImage1.value) else {
            return
        }
        do {
            let out = try analyser.computeHistogramEqualization(bitmap: bitmap)
            outImage.value = imageFrom(bitmap: out)
        } catch {
            presentError(error)
        }
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

}

