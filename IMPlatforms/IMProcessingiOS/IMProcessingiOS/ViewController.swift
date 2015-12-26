//
//  ViewController.swift
//  IMProcessingiOS
//
//  Created by denis svinarchuk on 24.12.15.
//  Copyright © 2015 ImageMetalling. All rights reserved.
//

import UIKit
import IMProcessing
import SMScrollView


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate{
    
    var imageView:IMPImageView!
    var filter:IMPHSVFilter!
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.view.backgroundColor = IMProcessing.css.background
        
        imageView = IMPImageView(frame: CGRectMake( 0, 20,
            self.view.bounds.size.width,
            self.view.bounds.size.height*3/4
            ))
        
        self.view.insertSubview(imageView, atIndex: 0)
        
        imageView.backgroundColor = UIColor.clearColor()
        
        
        //filter = IMPHSVFilter(context: imageView.context)
        //filter.adjustment.blues.hue = -0.5
        
        //imageView.filter = filter
        
        let albumButton = UIButton(type: .System)
        
        albumButton.backgroundColor = IMPColor.clearColor()
        albumButton.tintColor = IMPColor.whiteColor()
        albumButton.setImage(IMPImage(named: "select-photos"), forState: .Normal)
        albumButton.addTarget(self, action: "openAlbum:", forControlEvents: .TouchUpInside)
        
        albumButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(albumButton)
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[button(44)]-40-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["button" : albumButton]))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-20-[button(44)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["button" : albumButton]))
    }
    
    internal func openAlbum(sender:UIButton){
        imagePicker = UIImagePickerController()
    }
    
    
    private var imagePicker:UIImagePickerController!{
        didSet{
            self.imagePicker.delegate = self
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
            if let actualPicker = self.imagePicker{
                self.presentViewController(actualPicker, animated:true, completion:nil)
            }
        }
    }
    
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        let chosenImage:UIImage? = info[UIImagePickerControllerOriginalImage] as? UIImage
        
        if let actualImage = chosenImage{
            
            let image = IMPImageProvider(context: imageView.context, image: actualImage, maxSize: 1000)
            imageView?.source = image
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

