import 'package:flutter/material.dart';

class EcranMeteoRando extends StatelessWidget {
  const EcranMeteoRando({super.key});

  @override
  Widget build(BuildContext context) {
    // On utilise un DefaultTabController pour gérer facilement les 2 onglets
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Météo - Écouflant"),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.access_time), text: "Heure par heure"),
              Tab(icon: Icon(Icons.calendar_month), text: "Prévisions 5 jours"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ONGLET 1 : HEURE PAR HEURE (Style Agricole)
            _buildVueHeureParHeure(),

            // ONGLET 2 : TENDANCES 5 JOURS (Idéal pour planifier)
            _buildVue5Jours(),
          ],
        ),
      ),
    );
  }

  // --- VUE 1 : HEURE PAR HEURE ---
  Widget _buildVueHeureParHeure() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.umbrella_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                "Précipitations dans l'heure ?",
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: 12,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _buildLigneHoraire(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLigneHoraire(int index) {
    int heure = (DateTime.now().hour + index) % 24;
    String tempMax = "${21 - (index % 2)}°";
    String tempMin = "${14 - (index % 3)}°";
    String mmPluie = index == 1 || index == 2 ? "0,2 mm" : "0 mm";
    String pourcentPluie = index == 1 || index == 2 ? "70%" : "10%";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade600),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${heure.toString().padLeft(2, '0')}:00",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ),
          const Icon(Icons.cloudy_snowing, color: Colors.blueGrey),
          Column(
            children: [
              Text(
                tempMax,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tempMin,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Column(
            children: [
              const Icon(Icons.water_drop, color: Colors.blue, size: 16),
              Text(
                mmPluie,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                pourcentPluie,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Column(
            children: [
              Text(
                "26 km/h",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                "52 km/h",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- VUE 2 : PRÉVISIONS 5 JOURS ---
  Widget _buildVue5Jours() {
    List<String> jours = [
      "Aujourd'hui",
      "Demain (J+1)",
      "Après-demain (J+2)",
      "J+3",
      "J+4",
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: jours.length,
      separatorBuilder: (context, index) => const Divider(height: 20),
      itemBuilder: (context, index) {
        // Simulation de tendances météo changeantes pour la rando
        String tempMax = "${22 - index}°";
        String tempMin = "${13 - (index % 2)}°";
        String risquePluie = index == 1
            ? "80%"
            : "15%"; // Imaginons de la pluie demain
        IconData iconeMeteo = index == 1
            ? Icons.thunderstorm_rounded
            : Icons.wb_sunny_rounded;
        Color couleurIcone = index == 1 ? Colors.blueGrey : Colors.orange;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Nom du jour élargi pour s'aligner proprement
            SizedBox(
              width: 140,
              child: Text(
                jours[index],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Icône du temps global du jour
            Icon(iconeMeteo, color: couleurIcone, size: 28),
            // Températures Mini / Maxi
            Row(
              children: [
                Text(
                  tempMin,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(" / ", style: TextStyle(color: Colors.grey)),
                Text(
                  tempMax,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Risque de pluie global sur la journée
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue, size: 14),
                const SizedBox(width: 4),
                Text(
                  risquePluie,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
