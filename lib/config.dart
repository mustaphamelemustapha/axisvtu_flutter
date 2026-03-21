class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'AXISVTU_API_BASE',
    defaultValue: 'https://vtu-backend-8gsi.onrender.com/api/v1',
  );
}
