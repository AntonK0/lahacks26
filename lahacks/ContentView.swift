//
//  ContentView.swift
//  lahacks
//
//  Created by Timmy Phan on 4/24/26.
//

import SwiftUI

struct ContentView: View {
    @State private var scannedISBN: ISBN?

    var body: some View {
        if let scannedISBN {
            TutorARView(isbn: scannedISBN, scanAnotherBook: scanAnotherBook)
        } else {
            ISBNBarcodeScannerView(onISBNScanned: handleScannedISBN)
        }
    }

    private func handleScannedISBN(_ isbn: ISBN) {
        scannedISBN = isbn
    }

    private func scanAnotherBook() {
        scannedISBN = nil
    }
}

#Preview {
    ContentView()
}
