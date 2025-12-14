//
//  ProgressIndicator.swift
//  Re-Hearse_v1
//
//  Created by DEVANSH on 14/12/25.
//

import SwiftUI
import UIKit

struct ProgressIndicator: View {
    let step: Int   // 1, 2, or 3

    var body: some View {
        HStack(spacing: 10) {
            bar(isActive: step >= 1)
            bar(isActive: step >= 2)
            bar(isActive: step >= 3)
        }
        .padding(.bottom, 10)
    }

    private func bar(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isActive ? Color(UIColor.secondaryColor) : Color(UIColor.darkGray1))
            .frame(width: 40, height: 6)
    }
}

