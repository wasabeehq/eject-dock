# Validation du socle

Vérifications du 9 septembre 2026.

## Effectué

- Environnement : Mac Apple Silicon arm64, macOS 27.0, Swift 6.3.3.
- SDK choisi par xcrun : macOS 26.5. Les scripts définissent SDKROOT explicitement.
- `./scripts/test.sh` : 3 tests réussis, aucune erreur.
- `./scripts/archive.sh` : compilation release et assemblage réussis.
- Vérification de la signature ad hoc avec `codesign --verify --deep --strict`.
- Validation de Info.plist avec `plutil`.
- Vérification SHA-256 du ZIP local réussie.
- Lancement du bundle avec `open` : processus démarré et observé.

## Limites

Le contrôle de l’interface via l’outil de bureau a expiré. Le lancement du
processus ne valide donc pas le rendu du menu ni les interactions réelles.
Les tests des gestes couvrent le routage logique, pas les événements AppKit.

L’inventaire réel et sa réaction aux branchements restent à vérifier visuellement.
Le regroupement testé concerne les noms de disques entiers fournis en entrée ;
il ne prouve pas la résolution physique d’un conteneur APFS.

## À vérifier manuellement

- [ ] Icône visible et absence d’icône permanente dans le Dock.
- [ ] Clic gauche, clic droit, Option + clic et Contrôle + clic.
- [ ] Menu À propos et action Quitter.
- [ ] Apparition, disparition et changement des chemins de montage.
- [ ] Supports USB de test avec un et plusieurs volumes, dont APFS.
- [ ] Images disque montées : identification et regroupement en phase 3.
- [ ] Installation dans Applications, redémarrage et mise à jour locale.
- [ ] Compatibilité effective macOS 13 et Intel.

Les scénarios d’éjection, de persistance et de lancement à la connexion ne sont
pas encore implémentés. Aucun support de sauvegarde n’a été éjecté ou démonté.
Homebrew, Developer ID et notarisation restent à préparer et à valider.
