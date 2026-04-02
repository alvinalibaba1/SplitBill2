//
//  NavigationRouter.swift
//  SplitBill
//

import SwiftUI

class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    
    func push(_ destination: RouterDestination) {
        path.append(destination)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        if !path.isEmpty {
            path.removeLast(path.count)
        }
    }
}
