//
//  ViewController.swift
//  login-Example
//
//  Created by Ambroise Decouttere on 27/05/2020.
//  Copyright © 2020 infomaniak. All rights reserved.
//

import UIKit
import InfomaniakLogin

let clientId = "1d06ddb8-65d7-4e45-a1b1-276f5da71833"
let redirectUri = "com.infomaniak.auth://oauth2redirect"

class ViewController: UIViewController, InfomaniakLoginDelegate {
    func didFailLoginWith(error: String) {
        showError(error: error)
    }
    
    func didCompleteLoginWith(code: String, verifier: String) {
        InfomaniakLogin.getApiTokenUsing(code: code, codeVerifier: verifier) { (token, error) in }
    }

    @IBAction func login(_ sender: UIButton) {
        InfomaniakLogin.loginFrom(viewController: self, delegate: self, clientId: clientId, redirectUri: redirectUri)
    }
    
    @IBAction func webviewLogin(_ sender: UIButton) {
        InfomaniakLogin.setupWebviewNavbar(title: nil, color: UIColor.red)
        InfomaniakLogin.webviewLoginFrom(viewController: self, delegate: self, clientId: clientId, redirectUri: redirectUri, clearCookie: true)
    }
    
    
    func showError(error: String) {
        let alertController = UIAlertController(title: error, message:
        nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Fermer", style: .default, handler: {
            _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alertController, animated: true, completion: nil)
    }
    
}
