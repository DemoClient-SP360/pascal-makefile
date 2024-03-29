{$IFNDEF FPC_DOTTEDUNITS}
unit dbf_str;
{$ENDIF FPC_DOTTEDUNITS}

interface

{$I dbf_common.inc}
{$I dbf_str.inc}

implementation

initialization

  STRING_FILE_NOT_FOUND               := 'Ouverture: fichier non trouv�: "%s"';
  STRING_VERSION                      := 'TDbf V%d.%d';
  STRING_FEATURE_NOT_SUPPORTED_THIS_TABLELEVEL := 'Cette fonctionnalit� n''est pas support� dans tablelevel %d';
  
  STRING_RECORD_LOCKED                := 'Enregistrement verrouill�.';
  STRING_KEY_VIOLATION                := 'Violation de cl�. (doublon dans un index).'+#13+#10+
                                         'Index: %s'+#13+#10+'Enregistrement=%d Cle=''%s''';

  STRING_INVALID_DBF_FILE             := 'Fichier DBF invalide.';
  STRING_INVALID_DBF_FILE_FIELDERROR  := 'Fichier DBF invalide. Definition de champ invalide.'; //todo: verify field part
  STRING_FIELD_TOO_LONG               := 'Valeur trop longue: %d caract�res (ne peut d�passer %d).';
  STRING_INVALID_FIELD_COUNT          := 'Nombre de champs non valide: %d (doit �tre entre 1 et 4095).';
  STRING_INVALID_FIELD_TYPE           := 'Type de champ ''%s'' invalide pour le champ %s.';
  STRING_INVALID_VCL_FIELD_TYPE       := 'Impossible de cr�er le champ "%s", champ type %x VCL non support� par DBF';

  STRING_INDEX_BASED_ON_UNKNOWN_FIELD := 'Index bas� sur un champ inconnu %s';
  STRING_INDEX_BASED_ON_INVALID_FIELD := 'Impossible de contruire un index sur ce type de champ "%s"';
  STRING_INDEX_EXPRESSION_TOO_LONG    := 'R�sultat d''Index trop long pour "%s", >100 caract�res (%d).';
  STRING_INVALID_INDEX_TYPE           := 'Type d''index non valide: doit �tre string ou float';
  STRING_CANNOT_OPEN_INDEX            := 'Impossible d''ouvrir l''index: "%s"';
  STRING_TOO_MANY_INDEXES             := 'Impossible de cr�er l''index: trop d''index dans le fichier.';
  STRING_INDEX_NOT_EXIST              := 'L''index "%s" n''existe pas.';
  STRING_NEED_EXCLUSIVE_ACCESS        := 'Access exclusif requis pour cette op�ration.';
end.

