import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 250),
                  const SizedBox(height: 40),
                  const Text(
                    'Bem-vindo à Bolo & Bala!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Faça seu pedido online ou acompanhe o status de um pedido existente de forma fácil.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.cake, size: 28),
                      label: const Text(
                        'NOVO PEDIDO',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/home'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 28),
                      label: const Text(
                        'ACOMPANHAR PEDIDOS',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/client'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings,
                  color: Colors.grey),
              tooltip: 'Painel da Tia Cida',
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          ),
        ],
      ),
    );
  }
}
