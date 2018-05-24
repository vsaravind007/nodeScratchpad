//
//  ViewController.swift
//  Nodejs Scratchpad
//
//  Created by Aravind on 06/12/17.
//  Copyright © 2017 ARAVIND VS. All rights reserved.
//

import Cocoa
import Foundation
import JavaScriptCore
import Highlightr

class ViewController: NSViewController {
    @IBOutlet weak var runCodeButton: NSButton!
    @IBOutlet var outputView: NSTextView!
    @IBOutlet weak var statusText: NSTextField!
    @IBOutlet weak var codeView : NSTextView!
    @IBOutlet weak var clipView: NSClipView!
    
    var codeIsRunning: Bool = false
    var currentTask: Process!
    var dataObserver : NSObjectProtocol? = nil
    var outputPipe:Pipe? = nil
    var errpipe:Pipe? = nil
    let textStorage = CodeAttributedString()
    
    override func viewDidLoad() {
        super.viewDidLoad();
        // Highlighter
        textStorage.language = "javascript"
        textStorage.highlightr.setTheme(to: "github")
        textStorage.highlightr.theme.codeFont = NSFont(name: "Courier", size: 14)
        textStorage.addLayoutManager(codeView.layoutManager!)
        codeView.backgroundColor = (textStorage.highlightr.theme.themeBackgroundColor)!
        codeView.insertionPointColor = NSColor.black
        codeView.isAutomaticQuoteSubstitutionEnabled = false
        codeView.enabledTextCheckingTypes = 0
        codeView.lnv_setUpLineNumberView();
    }
    
    func runInJsCore(cmd: String) -> (output: String?, error: String){
        let context = JSContext()!
        context.evaluateScript("var console = { log: function(message) { _consoleLog(message) } }")
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("console.log: " + message)
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self), forKeyedSubscript: "_consoleLog" as (NSCopying & NSObjectProtocol)!)
        let tripleNum = context.evaluateScript(cmd)
        return(tripleNum!.toString(),"No error");
    }
    
    func captureStandardOutputAndRouteToTextView(_ task:Process) {
        outputPipe = Pipe()
        task.standardOutput = outputPipe
        errpipe = Pipe()
        task.standardError = errpipe
        outputPipe?.fileHandleForReading.waitForDataInBackgroundAndNotify()
        dataObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe?.fileHandleForReading , queue: nil) {
            notification in
            if let data = self.outputPipe?.fileHandleForReading.availableData {
                DispatchQueue.main.async {
                    if let outputString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                        let previousOutput = self.outputView.string
                        let nextOutput = previousOutput + "\n" + (outputString as String)
                        if (!nextOutput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty) {
                            self.outputView.string = nextOutput
                            print("NEXT OP" +  self.outputView.string)
                            let range = NSRange(location:nextOutput.count,length:0)
                            self.outputView.scrollRangeToVisible(range)
                        }
                    }
                }
                self.outputPipe?.fileHandleForReading.waitForDataInBackgroundAndNotify()
            }
        }
    }
    
    private func stringFromFileAndClose(file: FileHandle?) -> String? {
        if let data = file?.readDataToEndOfFile() {
            file?.closeFile()
            let output = String(data: data, encoding: String.Encoding.utf8)
            return output
        }
        return nil
    }
    
    func removeObservers() {
        if (dataObserver != nil) {
            NotificationCenter.default.removeObserver(dataObserver!)
        }
    }
    
    func updateStatus (buttonText: String, statusText: String){
        DispatchQueue.main.async( execute: {
            self.runCodeButton.title = buttonText
            self.statusText.stringValue = statusText
        })
    }
    
    func runCommand(view: NSTextView,cmd : String, args : String...) {
        let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        //2.
        taskQueue.async {
            if(self.codeIsRunning){
                self.currentTask.terminate();
                self.updateStatus(buttonText: "Run (⌘+R)",statusText: "Idle");
                self.codeIsRunning = false
                print("runCommand -async -return ")

                return
            }
            let task = Process()
            self.currentTask = task;
            task.qualityOfService = QualityOfService.userInteractive
            task.launchPath = cmd
            task.arguments = args
            self.captureStandardOutputAndRouteToTextView(task)
            self.codeIsRunning = true;
            task.launch()
            task.waitUntilExit()
            let errorFile = self.errpipe?.fileHandleForReading
            if let errorString = self.stringFromFileAndClose(file: errorFile) {
                DispatchQueue.main.async(execute: {
                    //Check if error string is empty
                    //By default, every Process task returns and empty error string.
                    if !errorString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        self.outputView.string = errorString
                        print(errorString)
                        let range = NSRange(location:errorString.count,length:0)
                        self.outputView.scrollRangeToVisible(range)
                    }
                })
                
            }
            self.codeIsRunning = false;
            self.updateStatus(buttonText: "Run (⌘+R)",statusText: "Idle");
        }
    }
    @IBAction func openGit(_ sender: Any) {
        if let url = URL.init(string: "https://github.com/vsaravind007/nodeScratchpad") {
            NSWorkspace.shared.open(url);
        }
    }
    
    @IBAction func closeButtonAction(_ sender: NSButton) {
        NSApp.terminate(self)
    }
    
    @IBAction func runCode(_ sender: NSButton) {
        DispatchQueue.main.async {
            self.outputView.string = "";
            print("output set to empty string")
            self.updateStatus(buttonText: "Stop",statusText: "Evaluating...")
            var code: String = "";
            code =  self.codeView.textStorage?.string ?? "";
            self.runCommand(view:self.outputView,cmd: "/usr/local/bin/node", args: "-e",code);
        }
    }
    
}

