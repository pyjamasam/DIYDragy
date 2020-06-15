//
//  SwipeToView.swift
//  SwipeToConfirm
//
//  Created by Chris Whiteford on 2020-05-19.
//  Copyright © 2020 Chris Whiteford. All rights reserved.
//


//https://www.youtube.com/watch?v=cKaNdzTg5X4

import SwiftUI

extension CGSize {
    static var inactiveThumbSize: CGSize {
        return CGSize(width: 70, height: 56)
    }
    
    static var activeThumbSize: CGSize {
        return CGSize(width: 85, height: 56)
    }
    
    static var trackSize: CGSize {
        return CGSize(width: 350, height: 56)
    }
}

extension SwipeToView {
    func onSwipeSuccess(_ action: @escaping () -> Void ) -> Self {
        var this = self
        this.actionSuccess = action
        
        return this
    }
}

struct SwipeToView: View {
    
    var label: String = "Swipe to ..."
    
    @State private var thumbSize: CGSize = CGSize.inactiveThumbSize
    @State private var dragOffset:CGSize = .zero
    @State private var isEnough = false
    
    private var actionSuccess: (() -> Void)?
    
    private let trackSize = CGSize.trackSize
    
    init (label: String) {
        self.label = label
    }
    
    var body: some View {
        ZStack {
            Capsule()
                .frame(width: trackSize.width, height: trackSize.height)
                .foregroundColor(.gray).opacity(0.8)
                .shadow(color: .black, radius: 2)
            
            Text(label)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .offset(x: 20, y:0)
                .opacity(Double(1 - ((self.dragOffset.width*2)/self.trackSize.width)))
            
            ZStack {
                Capsule()
                    .frame(width: thumbSize.width, height: thumbSize.height)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 20.0, weight: .bold))
                    .foregroundColor(.black)
            }
            .offset(x: getDragOffsetX(), y:0)
            .animation(Animation.spring(response: 0.3, dampingFraction: 0.8))
            .gesture(
                DragGesture()
                    .onChanged( { value in self.handleDragChanged(value) })
                    .onEnded({ _ in self.handleDragEnded()  })
            )
        }
    }
    
    
    private func indicateCanLiftFinger() -> Void {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func indicateSwipeWasSuccessfull() -> Void {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    
    private func getDragOffsetX() -> CGFloat {
        let clampedDragOffsetX = dragOffset.width.clamp(lower: 0, upper: trackSize.width - thumbSize.width)
        return -(trackSize.width/2 - thumbSize.width/2 - (clampedDragOffsetX))
    }
    
    private func handleDragChanged(_ value:DragGesture.Value) -> Void {
        self.dragOffset = value.translation
        
        let dragWidth = value.translation.width
        let targetDragWidth = self.trackSize.width - (self.thumbSize.width*2)
        let wasInitiated = dragWidth > 2
        let didReachTarget = dragWidth > targetDragWidth
        
        self.thumbSize = wasInitiated ? CGSize.activeThumbSize : CGSize.inactiveThumbSize
        
        if didReachTarget {
            if !self.isEnough  {
                self.indicateCanLiftFinger()
            }
            
            self.isEnough = true
        } else {
            self.isEnough = false
        }
    }
    
    private func handleDragEnded() -> Void {
        
        if self.isEnough {
            self.dragOffset = CGSize(width: self.trackSize.width - self.thumbSize.width, height: 0)
            
            if nil != self.actionSuccess {
                self.indicateSwipeWasSuccessfull()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.actionSuccess!()
                    
                    self.reset()
                }
            }
        } else {
            self.dragOffset = .zero
            self.thumbSize = CGSize.inactiveThumbSize
        }
    }
    
    private func reset() {
        self.dragOffset = .zero
        self.thumbSize = CGSize.inactiveThumbSize
        
        self.isEnough = false
    }
    
}

struct SwipeToView_Previews: PreviewProvider {
    static var previews: some View {
        SwipeToView(label: "Test Swipe")
    }
}
