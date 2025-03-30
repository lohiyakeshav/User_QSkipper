//
//  LocationView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import SwiftUI
import MapKit

struct LocationView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: AppConstants.defaultLatitude,
            longitude: AppConstants.defaultLongitude
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var navigateToHome = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                Text("Set Your Location")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.darkGray)
                
                Text("To provide you with the best service, we need to know your location.")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.mediumGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Map view
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, showsUserLocation: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .onChange(of: locationManager.location) { newLocation in
                        if let location = newLocation {
                            region.center = location.coordinate
                        }
                    }
                
                // Map overlay showing delivery availability
                VStack {
                    if locationManager.isDeliveryServiceAvailable() {
                        Text("Food ordering is available near \(locationManager.locationName)")
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(AppColors.primaryGreen)
                            .cornerRadius(10)
                    } else {
                        Text("Food ordering is available only near Galgotias University")
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(AppColors.errorRed)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 10)
            }
            
            // Current location info
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Location")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.darkGray)
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppColors.primaryGreen)
                    
                    Text(locationManager.locationName)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.darkGray)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.lightGray)
                .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Use current location
                QButton(title: "Use Current Location") {
                    // We've already fetched the current location automatically
                    // Just navigate to home
                    navigateToHome = true
                }
                
                // Use Galgotias University location
                QButton(title: "Use Galgotias University", style: .outline) {
                    locationManager.useDefaultLocation()
                    navigateToHome = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .navigationBarBackButtonHidden(true)
        .background(
            NavigationLink(
                destination: HomeView().navigationBarBackButtonHidden(true),
                isActive: $navigateToHome,
                label: { EmptyView() }
            )
        )
    }
}

#Preview {
    LocationView()
} 