# 🌱 EcoNavi iOS

<div align="center">

**An intelligent navigation app that helps you find eco-friendly routes while reducing your carbon footprint**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)](https://developer.apple.com/ios/)

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📱 About

EcoNavi is a revolutionary iOS navigation application that combines intelligent route planning with environmental consciousness. Unlike traditional navigation apps, EcoNavi helps you make travel decisions that are not only efficient but also environmentally friendly.

### 🎯 Mission

To empower users to make sustainable travel choices by providing real-time route optimization based on time, cost, and **carbon emissions**.

---

## ✨ Features

### 🗺️ **Smart Route Search**
- **Location-based search** with radius filtering (20km default)
- Real-time search suggestions with distance indicators
- Beautiful, modern UI with smooth animations
- Shows top 10 nearest places sorted by proximity

### 🎚️ **Route Optimization**
- **Customizable priorities** for route selection:
  - ⏱️ Fastest Time
  - 💰 Lowest Cost
  - 🌍 Lowest Emissions
- Interactive sliders to adjust preferences
- Skip option for quick route comparison

### 🚶 **Multi-Modal Route Comparison**
- Compare routes for different transportation modes:
  - 🚶 Walking
  - 🚴 Biking
  - 🚗 Driving
- Visual route selection with highlighted options
- Real-time emissions calculation

### 📊 **Emission Tracking**
- Track your carbon footprint
- View emission reduction tips
- Calculate CO₂ savings for each trip
- Environmental impact insights

### 🏆 **Rewards System**
- Earn credits for eco-friendly choices
- Unlock achievements
- Track your green journey
- Redeem rewards

### 📦 **Shipment Tracking**
- Track shipments with emission data
- Monitor delivery routes
- Environmental impact tracking

---

## 🚀 Installation

### Prerequisites

- **Xcode 15.0+**
- **iOS 15.0+**
- **Swift 5.9+**
- **macOS 13.0+** (for development)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/lakshiitakalyanasundaram/EcoNaviIOS.git
   cd EcoNaviIOS
   ```

2. **Open the project**
   ```bash
   open econavi.xcodeproj
   ```

3. **Configure Location Services**
   - The app requires location permissions
   - Enable location services in your device settings
   - Grant permissions when prompted

4. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

---

## 📖 Usage

### Getting Started

1. **Search for a Destination**
   - Tap the search bar at the top
   - Type your destination (minimum 2 characters)
   - Select from the suggested locations

2. **Set Route Priorities** (Optional)
   - Adjust sliders for Time, Cost, and Emissions
   - Click "Compare Routes" or "Skip" to proceed

3. **Compare Routes**
   - View available routes (Walk, Bike, Car)
   - Select your preferred mode of transportation
   - See real-time emissions data

4. **Track Your Impact**
   - View your emission savings
   - Check your rewards and achievements
   - Monitor your eco-friendly journey

### Key Features Walkthrough

#### 🔍 **Smart Search**
- Search results are filtered by proximity (within 20km radius)
- Results show distance in meters or kilometers
- Top 3 results are highlighted with star icons
- Smooth animations and modern UI

#### 🎯 **Route Priorities**
- Customize your route preferences
- Balance between speed, cost, and environmental impact
- Skip option available for quick navigation

#### 📈 **Emission Insights**
- View tips for reducing carbon footprint
- Calculate potential CO₂ savings
- Track your environmental impact over time

---

## 🏗️ Architecture

### Project Structure

```
econavi/
├── Assets.xcassets/          # App icons and images
├── ContentView.swift          # Main view with map and search
├── NavigateTabView.swift      # Navigation tab with route optimization
├── SearchService.swift        # Location-based search service
├── LocationManager.swift      # Core Location management
├── MapView.swift              # MapKit integration
├── EmissionsCalculator.swift  # Carbon footprint calculations
├── EcoRewardsManager.swift    # Rewards and achievements system
├── Models.swift               # Data models
├── ShipmentTabView.swift      # Shipment tracking
├── TrackTabView.swift         # Trip tracking
└── RewardsTabView.swift       # Rewards and achievements
```

### Key Components

- **SearchService**: Handles location-based search with radius filtering
- **LocationManager**: Manages Core Location services and permissions
- **EmissionsCalculator**: Calculates carbon footprint for different transport modes
- **EcoRewardsManager**: Manages rewards, credits, and achievements

### Technologies Used

- **SwiftUI** - Modern declarative UI framework
- **MapKit** - Apple's mapping and location services
- **Core Location** - Location services and geocoding
- **Combine** - Reactive programming for data flow
- **Core Data** - Local data persistence (if implemented)

---

## 🎨 UI/UX Highlights

- ✨ **Modern Design**: Clean, intuitive interface with smooth animations
- 🎯 **User-Friendly**: Easy-to-use search and route selection
- 🌈 **Visual Feedback**: Clear indicators for selected routes and priorities
- 📱 **Responsive**: Optimized for all iOS device sizes
- 🎭 **Material Design**: Uses iOS native materials and blur effects

---

## 🔮 Future Enhancements

- [ ] Real-time traffic integration
- [ ] Public transit route planning
- [ ] Social sharing of eco-friendly routes
- [ ] Community challenges and leaderboards
- [ ] Integration with electric vehicle charging stations
- [ ] Offline map support
- [ ] Widget support for quick route access
- [ ] Apple Watch companion app

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift style guidelines
- Write meaningful commit messages
- Add comments for complex logic
- Test on multiple iOS versions when possible

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Apple for providing excellent frameworks (SwiftUI, MapKit, Core Location)
- The open-source community for inspiration and tools
- All contributors and users of EcoNavi

---

## 📞 Support

If you have any questions or need help, please:
- Open an [Issue](https://github.com/lakshiitakalyanasundaram/EcoNaviIOS/issues)
- Check existing documentation
- Review the code comments

---

<div align="center">

**Made with ❤️ and 🌱 for a sustainable future**

⭐ Star this repo if you find it helpful!

</div>

