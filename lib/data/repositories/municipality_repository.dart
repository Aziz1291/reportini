import '../models/municipality.dart';

abstract interface class MunicipalityRepository {
  Future<List<Municipality>> listMunicipalities();
  Stream<List<Municipality>> watchMunicipalities();
  Future<Municipality> saveMunicipality(Municipality municipality);
  Future<void> deleteMunicipality(String id);
}
