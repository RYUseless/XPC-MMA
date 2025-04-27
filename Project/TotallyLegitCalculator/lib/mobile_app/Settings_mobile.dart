import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsScreenMobile extends StatefulWidget {
  const SettingsScreenMobile({super.key});

  @override
  State<SettingsScreenMobile> createState() => _SettingsScreenMobileState();
}

class _SettingsScreenMobileState extends State<SettingsScreenMobile> {
  final TextEditingController _myPortController = TextEditingController();
  final TextEditingController _peerIpController = TextEditingController();
  final TextEditingController _ownIpController = TextEditingController();
  final TextEditingController _shutdownMsgController = TextEditingController();
  bool _isDarkTheme = true;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8090/api/config'),
      );
      if (response.statusCode == 200) {
        final config = jsonDecode(response.body);
        setState(() {
          _myPortController.text = config['MY_PORT'].toString();
          _peerIpController.text = config['PEER_IP'] ?? '';
          _ownIpController.text = config['OWN_IP'] ?? '';
          _shutdownMsgController.text = config['SHUTDOWN_MSG'] ?? '';
        });
      } else {
        setState(() {
          _errorMessage =
              'Chyba načítání konfigurace: Server vrátil ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Chyba načítání konfigurace: $e';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    final config = {
      'MY_PORT': int.tryParse(_myPortController.text) ?? 0,
      'PEER_IP': _peerIpController.text,
      'OWN_IP': _ownIpController.text,
      'SHUTDOWN_MSG': _shutdownMsgController.text,
    };
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8090/api/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nastavení uloženo')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chyba při ukládání nastavení: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chyba: $e')));
    }
  }

  @override
  void dispose() {
    _myPortController.dispose();
    _peerIpController.dispose();
    _ownIpController.dispose();
    _shutdownMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: _isDarkTheme ? Colors.grey[850] : Colors.blue,
        ),
        body: Center(child: Text(_errorMessage)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _isDarkTheme ? Colors.grey[850] : Colors.blue,
      ),
      body: Container(
        color: _isDarkTheme ? Colors.grey[900] : Colors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Síťové nastavení'),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _myPortController,
                  label: 'MY_PORT',
                  hint: 'Zadejte port',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _peerIpController,
                  label: 'PEER_IP',
                  hint: 'Zadejte IP druhého peeru',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _ownIpController,
                  label: 'OWN_IP',
                  hint: 'Zadejte svou IP',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _shutdownMsgController,
                  label: 'SHUTDOWN_MSG',
                  hint: 'Zpráva pro ukončení spojení',
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Vzhled aplikace'),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  title: 'Tmavý režim',
                  value: _isDarkTheme,
                  onChanged: (value) {
                    setState(() {
                      _isDarkTheme = value;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveConfig,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Uložit nastavení',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _isDarkTheme ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: _isDarkTheme ? Colors.blue[300] : Colors.blue,
        ),
        hintStyle: TextStyle(
          color: _isDarkTheme ? Colors.grey[400] : Colors.grey[600],
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _isDarkTheme ? Colors.grey[600]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: _isDarkTheme ? Colors.grey[800] : Colors.white,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkTheme ? Colors.grey[600]! : Colors.grey[300]!,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(color: _isDarkTheme ? Colors.white : Colors.black87),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
