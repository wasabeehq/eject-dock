# EjectDock

Utilitaire macOS de barre de menus pour préparer l’éjection des disques d’un dock.

Projet open source sous [licence MIT](LICENSE).
Dépôt : [leokun/eject-dock](https://github.com/leokun/eject-dock).

État actuel : phase 1, socle en lecture seule. L’application affiche les disques
observés, leurs volumes et leurs chemins de montage. Aucune opération de
démontage ou d’éjection n’est encore implémentée.

## Développement

Prérequis : macOS 13 minimum, Swift 5.9 ou supérieur, SDK macOS et outils Apple.
Aucune dépendance externe. La compilation utilise l’architecture du Mac hôte.

```sh
./scripts/test.sh
./scripts/build.sh
open dist/EjectDock.app
```

L’icône d’éjection apparaît dans la barre de menus, sans icône permanente dans
le Dock. En l’absence de sélection configurée, le clic gauche ouvre le menu.
Le clic droit, Option + clic et Contrôle + clic sont également pris en charge.

```sh
./scripts/install.sh
open "$HOME/Applications/EjectDock.app"
./scripts/archive.sh
```

L’installation utilise `~/Applications` par défaut. Un autre dossier peut être
passé en argument au script. Quitter l’application avant de la remplacer.
La signature ad hoc et le ZIP local servent au développement sur ce Mac.
Ils ne constituent pas une distribution Developer ID notarisée.

## Structure

- `Sources/EjectDock` : cycle de vie, menu AppKit et observation Disk Arbitration.
- `Sources/EjectDockCore` : modèles et logique indépendante des API système.
- `Tests/EjectDockCoreTests` : regroupement des observations et gestes.
- `Resources` : métadonnées du bundle.
- `scripts` : tests, bundle signé localement, installation et archive.
- `docs/PLAN.md` : plan fourni, conservé comme référence.
- `docs/ROADMAP.md` : phases, décisions et limites techniques.
- `docs/VALIDATION.md` : vérifications effectuées et scénarios restant à tester.

Le regroupement actuel utilise la topologie de Disk Arbitration. Un disque
APFS synthétisé n’est pas encore relié à ses physical stores. Les images disque
ne sont pas encore qualifiées. Le menu ne présente donc aucune entrée comme
une cible sûre à éjecter. Les noms BSD servent uniquement pendant la session.

## Distribution

Le bundle utilise l’identifiant stable `fr.leo.ejectdock`. La version est dans
`VERSION` et `Resources/Info.plist` ; le build vérifie leur cohérence.
Une icône de bundle dédiée reste à ajouter ; la barre de menus utilise un
symbole système natif.

La publication de releases et le tap Homebrew sont une étape distincte.
Aucun cask ni workflow de publication de releases n’est créé tant que l’URL
réelle des archives, le propriétaire du tap et le circuit de signature ne sont
pas établis.
Voir la feuille de route pour les exigences de distribution.
