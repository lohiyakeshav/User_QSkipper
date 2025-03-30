//
//  LocationPickerView.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 29/03/25.
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @State private var navigateBack = false
    @StateObject private var locationManager = LocationManager.shared
    var onSelect: (String) -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: AppConstants.defaultLatitude,
            longitude: AppConstants.defaultLongitude
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Popular locations near Galgotias University
    private let popularLocations = [
        "Galgotias University",
        "Knowledge Park, Greater Noida",
        "Alpha 1, Greater Noida",
        "Alpha 2, Greater Noida",
        "Beta 1, Greater Noida",
        "Gamma 1, Greater Noida"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    navigateBack = true
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
                    .onChange(of: locationManager.location) { newLocation in
                        if let location = newLocation {
                            region.center = location.coordinate
                        }
                    }
                
                // Center pin
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(AppColors.primaryGreen)
                        .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                        .offset(y: -15)
                    
                    if locationManager.isDeliveryServiceAvailable() {
                        Text("Delivery available")
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.primaryGreen)
                            .cornerRadius(15)
                    } else {
                        Text("Delivery not available")
                            .font(AppFonts.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.errorRed)
                            .cornerRadius(15)
                    }
                }
            }
            
            // Current location
            Button {
                locationManager.requestLocation()
                onSelect(locationManager.locationName)
                navigateBack = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppColors.primaryGreen)
                    
                    Text("Use current location")
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
                .padding(.top, 20)
            }
            
            // Popular locations list
            VStack(alignment: .leading, spacing: 10) {
                Text("POPULAR LOCATIONS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                ForEach(popularLocations, id: \.self) { location in
                    Button {
                        onSelect(location)
                        navigateBack = true
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(AppColors.primaryGreen)
                            
                            Text(location)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.darkGray)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.mediumGray)
                        }
                        .padding()
                        .background(Color.white)
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .background(Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all))
        .background(
            NavigationLink(destination: EmptyView(), isActive: $navigateBack) {
                EmptyView()
            }
        )
    }
}

#Preview {
    LocationPickerView { _ in }
} 