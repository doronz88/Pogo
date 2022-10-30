//
//  ViewController.swift
//  Pogo
//
//  Created by Amy While on 12/09/2022.
//

import UIKit
import Darwin.POSIX

class ViewController: UIViewController {
    
    private var isWorking = false
    
    @IBOutlet weak var installButton: UIButton!
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var toolsButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var consoleTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let gitCommit = Bundle.main.infoDictionary?["REVISION"] as? String ?? "unknown"
        let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")"
        self.versionLabel.text = "v\(appVersion) (\(gitCommit))"
    }
    
    @IBAction func install(_ sender: Any) {
        guard !isWorking else { return }
        isWorking = true
        
        guard let deb = Bundle.main.path(forResource: "org.coolstar.sileo_2.4_iphoneos-arm64", ofType: ".deb") else {
            self.consoleTextView.error("[POGO] Could not find deb")
            return
        }
        
        self.consoleTextView.log("Installing Bootstrap")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.installBootstrap()
            
            let sudoChmodResult = spawn(command: "/var/jb/usr/bin/chmod", args: ["4755", "/var/jb/usr/bin/sudo"], root: true)
            if sudoChmodResult != KERN_SUCCESS {
                self?.consoleTextView.error("Failed to chmod sudo.\nerror = \(sudoChmodResult)")
            }
            let sudoChownResult = spawn(command: "/var/jb/usr/bin/chown", args: ["root:wheel", "/var/jb/usr/bin/sudo"], root: true)
            if sudoChownResult != KERN_SUCCESS {
                self?.consoleTextView.error("Failed to chown sudo.\nerror = \(sudoChmodResult)")
            }
            
            guard let rpcserver = Bundle.main.path(forAuxiliaryExecutable: "rpcserver") else {
                NSLog("[POGO] Could not find rpcserver")
                return
            }
            
            guard let rpcserver_plist = Bundle.main.path(forResource: "rpcserver", ofType: ".plist") else {
                NSLog("[POGO] Could not find rpcserver")
                return
            }
            
            self?.consoleTextView.log("Copying rpcserver")
            
            if KERN_SUCCESS != spawn(command: "/var/jb/usr/bin/cp", args: [rpcserver, "/var/jb/bin/rpcserver"], root: true) {
                self?.consoleTextView.error("Copy rpcserver failed")
            } else {
                spawn(command: "/var/jb/usr/bin/chmod", args: ["4755", "/var/jb/bin/rpcserver"], root: true)
                spawn(command: "/var/jb/usr/bin/chown", args: ["root:wheel", "/var/jb/bin/rpcserver"], root: true)
            }
            
            if KERN_SUCCESS != spawn(command: "/var/jb/usr/bin/cp", args: [rpcserver_plist, "/var/jb/Library/LaunchDaemons/rpcserver.plist"], root: true) {
                self?.consoleTextView.error("Copy rpcserver.plist failed")
            } else {
                spawn(command: "/var/jb/usr/bin/chmod", args: ["4755", "/var/jb/Library/LaunchDaemons/rpcserver.plist"], root: true)
                spawn(command: "/var/jb/usr/bin/chown", args: ["root:wheel", "/var/jb/Library/LaunchDaemons/rpcserver.plist"], root: true)
            }
            
            self?.consoleTextView.log("Preparing Bootstrap")
            
            let ret = spawn(command: "/var/jb/usr/bin/sh", args: ["/var/jb/prep_bootstrap.sh"], root: true)
            if ret != 0 {
                self?.consoleTextView.error("Failed to prepare bootstrap \(ret)")
            }
            DispatchQueue.main.async {
                if ret != 0 {
                    // if ret is -1, it probably means that amfi is not patched, show a alert
                    if ret == -1 {
                        let alert = UIAlertController(title: "Error", message: "Failed with -1, are you sure you have amfi patched?", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "NO", style: .default, handler: nil))
                        // show the alert
                        self?.present(alert, animated: true)
                    }
                    return
                }
                self?.consoleTextView.log("Installing Sileo")
                DispatchQueue.global(qos: .utility).async {
                    let ret = spawn(command: "/var/jb/usr/bin/dpkg", args: ["-i", deb], root: true)
                    DispatchQueue.main.async {
                        if ret != 0 {
                            self?.consoleTextView.log("Failed to install Sileo \(ret)")
                            return
                        }
                        self?.consoleTextView.log("UICache Sileo")
                        DispatchQueue.global(qos: .utility).async {
                            let ret = spawn(command: "/var/jb/usr/bin/uicache", args: ["-p", "/var/jb/Applications/Sileo-Nightly.app"], root: true)
                            DispatchQueue.main.async {
                                if ret != 0 {
                                    self?.consoleTextView.log("failed to uicache \(ret)")
                                    return
                                }
                                self?.consoleTextView.log("uicache succesful, have fun!")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func installBootstrap() {
        let mountSpawnResult = spawn(command: "/sbin/mount", args: ["-uw", "/private/preboot"], root: true)
        if mountSpawnResult != KERN_SUCCESS {
            self.consoleTextView.error("Failed to remount /private/preboot to read-write\nerror=\(mountSpawnResult)")
            return
        }
        
        guard let helper = Bundle.main.path(forAuxiliaryExecutable: "PogoHelper") else {
            self.consoleTextView.error("[POGO] Could not find helper?")
            return
        }
        
        guard let tar = Bundle.main.path(forResource: "bootstrap", ofType: "tar") else {
            self.consoleTextView.error("[POGO] Failed to find bootstrap")
            return
        }
        
        let ret = spawn(command: helper, args: ["-i", tar], root: true)
        if ret != 0 {
            self.consoleTextView.error("Error Installing Helper\nerror = \(ret)")
            return
        }
    }
    
    
    @IBAction func remove(_ sender: Any) {
        guard !isWorking else { return }
        isWorking = true
        guard let helper = Bundle.main.path(forAuxiliaryExecutable: "PogoHelper") else {
            self.consoleTextView.error("[POGO] Could not find helper?")
            return
        }
        self.consoleTextView.log("Unregistering apps")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // for every .app file in /var/jb/Applications, run uicache -u
            let fm = FileManager.default
            let apps = try? fm.contentsOfDirectory(atPath: "/var/jb/Applications")
            for app in apps ?? [] {
                if app.hasSuffix(".app") {
                    let ret = spawn(command: "/var/jb/usr/bin/uicache", args: ["-u", "/var/jb/Applications/\(app)"], root: true)
                    DispatchQueue.main.async {
                        if ret != 0 {
                            self?.consoleTextView.error("failed to unregister \(ret)")
                            return
                        }
                    }
                }
            }
            self?.consoleTextView.error("Removing Strap")
            let ret = spawn(command: helper, args: ["-r"], root: true)
            DispatchQueue.main.async {
                if ret != 0 {
                    self?.consoleTextView.error("Failed to remove :( \(ret)")
                    return
                }
                self?.consoleTextView.log("omg its gone!")
            }
        }
    }
    
    @objc private func runUiCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // for every .app file in /var/jb/Applications, run uicache -p
            let fm = FileManager.default
            let apps = try? fm.contentsOfDirectory(atPath: "/var/jb/Applications")
            for app in apps ?? [] {
                if app.hasSuffix(".app") {
                    let ret = spawn(command: "/var/jb/usr/bin/uicache", args: ["-p", "/var/jb/Applications/\(app)"], root: true)
                    DispatchQueue.main.async {
                        if ret != 0 {
                            self?.consoleTextView.error("failed to uicache \(ret)")
                            return
                        }
                        self?.consoleTextView.log("uicache succesful, have fun!")
                    }
                }
            }
            
        }
    }
    
    // tools popup
    
    @IBAction func tools(_ sender: Any) {
        let alert = UIAlertController(title: "Tools", message: "Select", preferredStyle: .actionSheet)
        let popover = alert.popoverPresentationController
        popover?.sourceView = view
        popover?.sourceRect = CGRect(x: 0, y: 0, width: 64, height: 64)
        
        alert.addAction(UIAlertAction(title: "uicache", style: .default, handler: { _ in
            self.runUiCache()
        }))
        alert.addAction(UIAlertAction(title: "Remount Preboot", style: .default, handler: { _ in
            spawn(command: "/sbin/mount", args: ["-uw", "/private/preboot"], root: true)
            self.consoleTextView.log("Remounted Preboot R/W")
        }))
        alert.addAction(UIAlertAction(title: "Launch Daemons", style: .default, handler: { _ in
            spawn(command: "/var/jb/bin/launchctl", args: ["bootstrap", "system", "/var/jb/Library/LaunchDaemons"], root: true)
            self.consoleTextView.log("done")
        }))
        alert.addAction(UIAlertAction(title: "Respring", style: .default, handler: { _ in
            spawn(command: "/var/jb/usr/bin/sbreload", args: [], root: true)
        }))
        alert.addAction(UIAlertAction(title: "Do All", style: .default, handler: { _ in
            self.runUiCache()
            spawn(command: "/sbin/mount", args: ["-uw", "/private/preboot"], root: true)
            spawn(command: "/var/jb/bin/launchctl", args: ["bootstrap", "system", "/var/jb/Library/LaunchDaemons"], root: true)
            spawn(command: "/var/jb/usr/bin/sbreload", args: [], root: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

