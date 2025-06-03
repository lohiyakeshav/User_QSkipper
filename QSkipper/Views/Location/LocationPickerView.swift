//
//  LocationPickerView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 29/03/25.
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationManager = LocationManager.shared
    var onSelect: (String) -> Void
    @State private var navigateToHome = false
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: AppConstants.defaultLatitude,
            longitude: AppConstants.defaultLongitude
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with custom back button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                
                Spacer()
                
                Text("Select Location")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.darkGray)
                
                Spacer()
                
                // Empty view for balance
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            
            // Map
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .onAppear {
                        // Always show Galgotias University location on the map
                        region.center = CLLocationCoordinate2D(
                            latitude: AppConstants.defaultLatitude,
                            longitude: AppConstants.defaultLongitude
                        )
                    }
                
                // Center pin
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(AppColors.primaryGreen)
                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                        .offset(y: -15)
                    
                    Text("Pickup available")
                        .font(AppFonts.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primaryGreen)
                        .cornerRadius(15)
                }
            }
            
            // Available location heading and button
            VStack(alignment: .leading, spacing: 10) {
                Text("AVAILABLE LOCATION")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                Button {
                    // Always set location to Galgotias University
                    onSelect("Galgotias University")
                    // Dismiss this view
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(AppColors.primaryGreen)
                        
                        Text("Galgotias University")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.darkGray)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(AppColors.mediumGray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    .padding(.horizontal, 20)
                }
                
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
            }
            
            Spacer()
        }
        .onAppear {
            // No need to request user location since we're always using Galgotias University
        }
        .background(Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all))
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    LocationPickerView { _ in }
} 