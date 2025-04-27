import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController(
    text: 'localhost',
  );
  final TextEditingController _portController = TextEditingController(
    text: '8080',
  );
  bool _useTLS = true;
  String _backendPath = '';
  bool _isDarkTheme = true;

  @override
  void initState() {
    super.initState();
    // Zde můžete načíst nastavení z nějakého úložiště
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    // Zde můžete uložit nastavení do nějakého úložiště
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Settings saved')));
  }

  void _selectBackendPath() async {
    // Zde by byl kód pro výběr cesty k backendu
    setState(() {
      _backendPath = '/selected/path/to/backend';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        backgroundColor: _isDarkTheme ? Colors.grey[850] : Colors.blue,
      ),
      body: Container(
        color: _isDarkTheme ? Colors.grey[900] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Network Settings'),
              SizedBox(height: 16),
              _buildTextField(
                controller: _ipController,
                label: 'Server IP Address',
                hint: 'Enter server IP address',
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _portController,
                label: 'Port',
                hint: 'Enter port number',
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              _buildSwitchTile(
                title: 'Use TLS Encryption',
                value: _useTLS,
                onChanged: (value) {
                  setState(() {
                    _useTLS = value;
                  });
                },
              ),
              SizedBox(height: 24),
              _buildSectionHeader('Backend Settings'),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _backendPath.isEmpty
                          ? 'No backend path selected'
                          : _backendPath,
                      style: TextStyle(
                        fontSize: 16,
                        color: _isDarkTheme ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _selectBackendPath,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Select'),
                  ),
                ],
              ),
              SizedBox(height: 24),
              _buildSectionHeader('Appearance'),
              SizedBox(height: 16),
              _buildSwitchTile(
                title: 'Dark Theme',
                value: _isDarkTheme,
                onChanged: (value) {
                  setState(() {
                    _isDarkTheme = value;
                  });
                },
              ),
              Spacer(),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Save Settings', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
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
          borderSide: BorderSide(color: Colors.blue),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
