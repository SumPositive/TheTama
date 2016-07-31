//
//  ThetaViewController.swift
//  TheTama
//
//  Created by masa on 2016/07/28.
//  Copyright © 2016年 Azukid. All rights reserved.
//

import UIKit
import WebKit


class ThetaViewController: UIViewController {

	//@IBOutlet weak var webBaseView:UIView!
	
	private var webView: WKWebView!
	
	
    override func viewDidLoad() {
        super.viewDidLoad()

		//3.WebKitのインスタンス作成!
		webView = WKWebView()
		
		//4.ここでWebKitをviewに紐付け
		self.view = webView!
		//self.webBaseView.addSubview(webView)
		
		
		
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		
		//webView.frame = self.webBaseView.bounds
		//webView.sizeToFit()

		//
		html_copy()
		
//		//5.URL作って、表示させる！
//		let url = NSURL(string:"http://www.yahoo.co.jp/")
//		let req = NSURLRequest(URL:url!)
//		webView.loadRequest(req)
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
	
	
	
	
	private func html_copy() {
		let fileManager = NSFileManager.defaultManager()
		
		// From: Bundle
		let resourcePath = NSBundle.mainBundle().bundlePath  //.pathForResource("html/index", ofType: "html")
		let fromDir = resourcePath + "/html"
		print("fromDir: \(fromDir)")
		
//		// 再帰的にファイルの一覧を取得する
//		if let paths = fileManager.enumeratorAtPath(fromDir) {
//			while let file = paths.nextObject() as? String {
//				print(" From: " + file)
//			}
//		}

		// To: Library/　ディレクトリがなかったら作成する
		let libraryUrl = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
		let libraryDir = libraryUrl
		let toDir = libraryDir + "/html"
		print("toDir: \(toDir)")
		
		do {
			try fileManager.copyItemAtPath(fromDir, toPath: toDir)
		}
		catch {
			//self.navigationController?.popViewControllerAnimated(true)
			//return
		}

		// 再帰的にファイルの一覧を取得する
		if let paths = fileManager.enumeratorAtPath(toDir) {
			while let file = paths.nextObject() as? String {
				print(" To: " + file)
			}
		}
		
		//5.URL作って、表示させる！
		//let url = NSURL(string:"file://\(toDir)/index.html")
		let url = NSURL(fileURLWithPath: "\(toDir)/test.html")
		print("url: \(url)")
		let req = NSURLRequest(URL:url)
		webView!.loadRequest(req)
	}

}
