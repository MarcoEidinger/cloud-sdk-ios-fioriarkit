//
//  LineView.swift
//  
//
//  Created by O'Brien, Patrick on 4/22/21.
//

import SwiftUI

internal struct LineView: View {
    @State private var opacity: Double = 0
    
    @Binding var displayLine: Bool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var screen = UIScreen.main.bounds
    var gradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [.white, Color(red: 10/255, green: 110/255, blue: 209/255)]),
                       startPoint: UnitPoint(x: startPoint.x / screen.width, y: startPoint.y / screen.height),
                       endPoint: UnitPoint(x: endPoint.x / screen.width, y: endPoint.y / screen.height))
    }
    
    internal init(displayLine: Binding<Bool>, startPoint: CGPoint, endPoint: CGPoint) {
        self._displayLine = displayLine
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
    
    internal var body: some View {
        if displayLine {
            Path { path in
                path.move(to: endPoint)
                path.addLine(to: startPoint)
            }
            .stroke(gradient, lineWidth: 3)
            .opacity(opacity)
            .animateOnAppear(animation: Animation.easeIn(duration: 0.3)) {
                opacity = 1
                // Delay Fade Out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(Animation.easeOut(duration: 0.3)) {
                        opacity = 0
                    }
                    // Delay reseting Displaying line or else the animation stops recieving updated positions appearing to be frozen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        displayLine = false
                    }
                }
            }
        }
    }
}