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
    
    var inputImage1 = Variable<NSImage?>(nil)
    var inputImage2 = Variable<NSImage?>(nil)
    var processedImage = Variable<NSImage?>(nil)
    
    var currentFilter: FilterStore = .hilo
    
    let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        inputImage1.asObservable().bind(to: firstInputImageView.rx.image).disposed(by: bag)
        inputImage2.asObservable().bind(to: secondInputImageView.rx.image).disposed(by: bag)
        processedImage.asObservable().bind(to: processedImageView.rx.image).disposed(by: bag)
        
        filterSelection.removeAllItems()
        for filter in FilterStore.allCases {
            filterSelection.addItem(withTitle: "\(filter)")
        }
        filterSelection.selectItem(at: currentFilter.hashValue)
        
        assignImage()
        processCurrentFilter()
    }
    
    private func assignImage() {
        
        processedImage.value = nil
        
        switch currentFilter {
        case .grayscale:
            inputImage1.value = NSImage(named: NSImage.Name.imageForGrayscale)
            inputImage2.value = nil
        case .hilo, .divide:
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
        
        processedImage.value = imageFrom(bitmap: analyser.imageDivideMPS(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle) )
//        processedImage.value = imageFrom(bitmap: analyser.imageSubstractMPS(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle) )
    }
    
    private func processHilo() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1.value), let bitmapSpeckle = bitmapFrom(image: inputImage2.value) else { return }
        
        processedImage.value = imageFrom(bitmap: analyser.hiloFrom(bitmapUniform: bitmapUniform, bitmapSpeckle: bitmapSpeckle) )
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

