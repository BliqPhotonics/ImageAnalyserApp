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
    case hilo
    
    static var allCases: [FilterStore] { return [.grayscale, .hilo] }
}

class ViewController: NSViewController {
    
    let analyser = ImageAnalyser.sharedInstance
    
    @IBOutlet weak var filterSelection: NSPopUpButton!
    @IBOutlet weak var firstInputImageView: NSImageView!
    @IBOutlet weak var secondInputImageView: NSImageView!
    @IBOutlet weak var processedImageView: NSImageView!
    
    var inputImage1: NSImage?
    var inputImage2: NSImage?
    var processedImage: NSImage?
    
    var currentFilter: FilterStore = .grayscale
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        filterSelection.removeAllItems()
        for filter in FilterStore.allCases {
            filterSelection.addItem(withTitle: "\(filter)")
        }
        
        filterSelection.selectItem(at: currentFilter.hashValue)
        debugPrint("\(currentFilter)")
        
//        assignImage()
    }
    
    private func assignImage() {
        
        
        processedImage = nil
        
        switch currentFilter {
        case .grayscale:
            inputImage1 = NSImage(named: NSImage.Name.imageForGrayscale)
            inputImage2 = nil
        case .hilo:
            inputImage1 = NSImage(named: NSImage.Name.imageUniform)
            inputImage2 = NSImage(named: NSImage.Name.imageSpeckle)
        }
        
        firstInputImageView.image = inputImage1
        secondInputImageView.image = inputImage2
        
        processedImageView.image = processedImage
    }

    @IBAction func selectFilter(_ sender: NSPopUpButton) {
        currentFilter = FilterStore(rawValue: sender.indexOfSelectedItem) ?? .grayscale
        debugPrint("Selected \(currentFilter) filter")
        
        assignImage()
        
        switch currentFilter {
        case .grayscale:
            processGrayscale()
        case .hilo:
            processHilo()
        }
        
    }
    
    private func processGrayscale() {
        debugPrint("Processing Image with \(currentFilter)")
        guard let data = inputImage1?.tiffRepresentation else {
            debugPrint("No Image to process")
            return
        }
        let bitmap = NSBitmapImageRep(data: data)
        guard let outBitmap = analyser.computeGrayscaleFrom(bitmap: bitmap), let cgImage = outBitmap.cgImage else { return }
        
        processedImage = NSImage(cgImage: cgImage, size: outBitmap.size)
        processedImageView.image = processedImage
    }
    
    private func processHilo() {
        debugPrint("Processing Image with \(currentFilter)")
    }
    
}

