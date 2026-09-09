# Feuille de route

## Phase 1 : socle

- [x] Package Swift, AppKit et composants séparés.
- [x] Icône de barre de menus et routage des gestes.
- [x] Observation des apparitions, disparitions et changements de volumes.
- [x] Inventaire en lecture seule et tests de la logique isolée.
- [x] Scripts de build et d’assemblage du bundle.
- [ ] Validation visuelle des gestes sur le Mac.

## Phase 2 : fonction principale

- [ ] Capturer des métadonnées de supports de test APFS et USB.
- [ ] Résoudre la topologie physique APFS, y compris plusieurs physical stores.
- [ ] Exclure les disques internes, les supports système et les types inconnus.
- [ ] Définir une identité persistante avec UUID et métadonnées matérielles.
- [ ] Refuser les collisions et identités ambiguës, même à nom identique.
- [ ] Ajouter PreferencesStore et gérer les sélections absentes.
- [ ] Injecter les opérations natives dans EjectionService.
- [ ] Revalider chaque cible immédiatement avant son opération.
- [ ] Démonter normalement, puis éjecter avec confirmation système.
- [ ] Bloquer les demandes concurrentes, gérer les résultats indépendamment.
- [ ] Conserver un état en attente lors d’un délai dépassé.
- [ ] Tester les déconnexions, disques occupés et échecs partiels.

## Phase 3 : compléments

- [ ] DiskImageService : inventaire structuré et regroupement des images.
- [ ] Valider `hdiutil info -plist` comme adaptateur éventuel.
- [ ] Actions pour tous les externes et toutes les images.
- [ ] Réglages en menu, lancement à la connexion avec SMAppService.
- [ ] Option d’inclusion des images désactivée par défaut.
- [ ] États accessibles : prêt, en cours, terminé, partiel, absent.
- [ ] Confirmation visible sans autorisation de notifications.

## Phase 4 : installation locale

- [x] Bundle, identifiant, scripts de build, installation et ZIP local.
- [ ] Icône de bundle dédiée.
- [ ] Vérifier le lancement depuis Applications et les mises à jour locales.
- [ ] Vérifier conservation des préférences et ouverture de session.

## Phase 5 : distribution

- [x] Application publique sous licence MIT : leokun/eject-dock.
- [ ] Choisir le tap et l’architecture de distribution.
- [ ] Ajouter la CI macOS après validation du socle local.
- [ ] Contrôler l’égalité tag, VERSION et version du bundle.
- [ ] Signer Developer ID, activer Hardened Runtime, notariser et agrafer.
- [ ] Vérifier le bundle final, archiver, calculer SHA-256 et publier.
- [ ] Créer le tap homebrew-tools et son cask avec les valeurs vérifiées.
- [ ] Tester installation, mise à jour, désinstallation et nettoyage explicite.

## Décisions initiales

macOS 13 minimum : SMAppService.mainApp est disponible à partir de macOS 13,
vérifié dans le header du SDK local. Les API d’observation Disk Arbitration
retenues sont disponibles depuis macOS 10.4. La compatibilité effective avec
macOS 13 nécessite encore un test sur cette version.

Swift Package Manager et AppKit suffisent pour le socle. Swift tools 5.9
permet de garder une base simple sans imposer Swift 6 aux contributeurs.
Les callbacks Disk Arbitration sont exécutés sur la boucle principale.

La topologie logique observée ne prouve ni l’identité persistante ni la nature
physique du périphérique. La phase 2 doit résoudre ces deux points avant
d’exposer la moindre action d’éjection. Ne jamais inférer une identité à partir
d’un nom ou d’un numéro BSD seul.

Aucune éjection réelle, publication distante ou modification de Gatekeeper
n’est nécessaire à cette première phase.
