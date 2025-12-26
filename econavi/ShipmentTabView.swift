import SwiftUI

struct ShipmentTabView: View {

    // USER INPUT
    @State private var distanceKm = ""
    @State private var weightKg = ""
    @State private var method = "freightTruck"

    // UI STATE
    @State private var calculated = false
    @FocusState private var focusedField: Field?

    enum Field {
        case distance, weight
    }

    // CALCULATIONS (USING YOUR EXISTING LOGIC)
    private var emissions: Double {
        guard
            let d = Double(distanceKm),
            let w = Double(weightKg),
            calculated
        else { return 0 }

        return EmissionsCalculatorIndia.calculateFreightEmissions(
            method: method,
            weightKg: w,
            distanceKm: d
        )
    }

    private var credits: Int {
        EmissionsCalculatorIndia.calculateCarbonCredits(
            savedEmissionsGrams: emissions
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                header

                inputCard

                actionButtons

                if calculated {
                    resultCard
                    insightCard
                }
            }
            .padding()
        }
        // ✅ KEYBOARD DONE BUTTON
        Button {
            // ✅ Dismiss keyboard
            focusedField = nil

            // ✅ Trigger calculation
            calculated = true
        } label: {
            Label("Calculate Emissions", systemImage: "equal.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(distanceKm.isEmpty || weightKg.isEmpty)

    }

    // MARK: HEADER
    private var header: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.blue)
            Text("Shipment Emissions")
                .font(.title2.bold())
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: INPUT CARD
    private var inputCard: some View {
        VStack(spacing: 16) {

            Picker("Transport", selection: $method) {
                Text("Truck").tag("freightTruck")
                Text("Rail").tag("freightRail")
                Text("Ship").tag("freightShip")
                Text("Air").tag("freightAir")
            }
            .pickerStyle(.segmented)

            inputField(
                title: "Distance (km)",
                text: $distanceKm,
                field: .distance
            )

            inputField(
                title: "Weight (kg)",
                text: $weightKg,
                field: .weight
            )
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

    // MARK: ACTION BUTTONS
    private var actionButtons: some View {
        HStack(spacing: 12) {

            // CALCULATE
            Button {
                focusedField = nil
                calculated = true
            } label: {
                Label("Calculate", systemImage: "equal.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(distanceKm.isEmpty || weightKg.isEmpty)

            // RESET
            Button {
                distanceKm = ""
                weightKg = ""
                calculated = false
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: RESULT CARD
    private var resultCard: some View {
        VStack(spacing: 12) {

            Text("Estimated Emissions")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(EmissionsCalculatorIndia.formatEmissions(emissions))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.green)

            HStack {
                Image(systemName: "leaf.fill")
                Text("+\(credits) carbon credits")
            }
            .font(.caption.bold())
            .foregroundStyle(.green)

        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    // MARK: INSIGHT
    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eco Insight")
                .font(.headline)

            Text(suggestionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    // MARK: INPUT FIELD
    private func inputField(
        title: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: field)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: SUSTAINABILITY LOGIC
    private var suggestionText: String {
        switch method {
        case "freightTruck":
            return "Switching to Rail can reduce emissions by up to 65%."
        case "freightAir":
            return "Air freight is carbon intensive. Consider Ship or Rail."
        case "freightShip":
            return "Ship transport is one of the greenest freight options."
        case "freightRail":
            return "Rail is a low-carbon choice. Great decision 🌱"
        default:
            return ""
        }
    }
}

