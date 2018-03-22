//
//  ViewController.swift
//  ImageAnalyserApp
//
//  Created by Steve Begin on 2018-03-22.
//  Copyright © 2018 BLIQc. All rights reserved.
//

import Cocoa
import ImageAnalyser

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
    
    var inputImage1: NSImage? {
        didSet {
            firstInputImageView.image = inputImage1
        }
    }
    var inputImage2: NSImage? {
        didSet {
            secondInputImageView.image = inputImage2
        }
    }
    var processedImage: NSImage? {
        didSet {
            processedImageView.image = processedImage
        }
    }
    
    var currentFilter: FilterStore = .hilo
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        filterSelection.removeAllItems()
        for filter in FilterStore.allCases {
            filterSelection.addItem(withTitle: "\(filter)")
        }
        filterSelection.selectItem(at: currentFilter.hashValue)
        
        assignImage()
        processCurrentFilter()
        
    }
    
    private func assignImage() {
        processedImage = nil
        
        switch currentFilter {
        case .grayscale:
            inputImage1 = NSImage(named: NSImage.Name.imageForGrayscale)
            inputImage2 = nil
        case .hilo, .divide:
            inputImage1 = NSImage(named: NSImage.Name.imageUniform)
            inputImage2 = NSImage(named: NSImage.Name.imageSpeckle)
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
        processedImage = imageFrom(bitmap: analyser.computeGrayscaleFrom(bitmap: bitmapFrom(image: inputImage1)))
    }
    
    private func processDivide() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1), let bitmapSpeckle = bitmapFrom(image: inputImage2) else { return }
        
        processedImage = imageFrom(bitmap: analyser.imageDivideMPS(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle) )
//        processedImage = imageFrom(bitmap: analyser.imageSubstractMPS(bitmap1: bitmapUniform, bitmap2: bitmapSpeckle) )
    }
    
    private func processHilo() {
        guard let bitmapUniform = bitmapFrom(image: inputImage1), let bitmapSpeckle = bitmapFrom(image: inputImage2) else { return }
        
        processedImage = imageFrom(bitmap: analyser.hiloFrom(bitmapUniform: bitmapUniform, bitmapSpeckle: bitmapSpeckle) )
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

