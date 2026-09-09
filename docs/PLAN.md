# Projet EjectDock

Créer une petite application macOS permettant d’éjecter en un clic les disques présélectionnés avant de débrancher une station d’accueil.

## 1. Objectif et périmètre

Usage principal :
- Un disque externe de sauvegarde reste habituellement connecté au dock.
- L’utilisateur sélectionne une fois ce disque dans les réglages.
- Un clic gauche sur l’icône de barre de menus lance son éjection.
- L’application confirme le résultat avant que l’utilisateur débranche le dock.

L’application doit :
- Fonctionner uniquement dans la barre de menus, sans icône permanente dans le Dock.
- Permettre de sélectionner plusieurs disques pour l’action principale.
- Mémoriser cette sélection entre les redémarrages et les branchements.
- Proposer une action pour éjecter toutes les images disque montées.
- Être installable et actualisable avec Homebrew.

Ne pas ajouter en première version :
- Éjection automatique à la mise en veille.
- Synchronisation, compte utilisateur ou télémétrie.
- Mise à jour automatique intégrée à l’application.
- Fonctionnalités Windows ou Linux.
- Éjection forcée ou arrêt automatique des processus bloquants.

## 2. Comportement de l’interface

### Clic gauche

Éjecter les disques sélectionnés qui sont actuellement connectés.

- Ne pas demander de confirmation à chaque clic.
- Ignorer les disques sélectionnés qui sont absents.
- Empêcher les opérations concurrentes déclenchées par des clics répétés.
- Si aucune sélection n’a encore été configurée, ouvrir le menu.
- Si la sélection existe mais qu’aucun disque correspondant n’est connecté,
  afficher un état explicite sans éjecter d’autres disques.

### Clic droit

Ouvrir un menu natif macOS.

Prévoir également Option + clic pour ouvrir ce menu.
Vérifier le comportement du clic secondaire et de Contrôle + clic.

Ne pas utiliser Commande + clic comme geste principal alternatif,
afin de préserver les interactions habituelles de la barre de menus.

### Organisation proposée du menu

- Éjecter la sélection
- Éjecter tous les disques externes
- Éjecter toutes les images disque
- Séparateur
- Disques externes
  - Un sous-menu par disque physique :
    - État et volumes associés
    - Éjecter maintenant
    - Inclure dans l’éjection au clic gauche
- Images disque
  - Une entrée par image montée :
    - Éjecter maintenant
- Séparateur
- Réglages
- À propos
- Quitter

Une sélection persistante doit rester consultable et supprimable
même lorsque le disque concerné est débranché.

### Réglages

- Lancement à l’ouverture de session.
- Gestion des disques sélectionnés, y compris ceux qui sont absents.
- Option désactivée par défaut :
  inclure toutes les images disque dans l’action du clic gauche.

Commencer avec un menu de réglages.
Créer une fenêtre SwiftUI seulement si cela améliore réellement l’usage.

### Retour visuel

Distinguer :
- Sélection connectée et prête à être éjectée.
- Éjection en cours.
- Éjection terminée.
- Résultat partiel ou échec.
- Aucun disque sélectionné connecté.

Fournir une info-bulle et des libellés accessibles.
Ne pas utiliser uniquement la couleur pour transmettre l’état.

La réussite doit être visible sans dépendre de l’autorisation
des notifications macOS.

Attention au libellé :
- « Sélection éjectée » si seuls les disques sélectionnés ont été éjectés.
- Ne pas annoncer « Vous pouvez débrancher le dock » si d’autres disques
  externes restent montés.

## 3. Stack technique

- Swift.
- AppKit pour NSStatusItem, les clics et les menus.
- SwiftUI facultatif pour une fenêtre de réglages.
- Disk Arbitration pour observer les disques et effectuer
  les opérations natives de démontage et d’éjection.
- UserDefaults pour les préférences simples.
- ServiceManagement pour le lancement à l’ouverture de session,
  selon la version minimale de macOS retenue.
- Journalisation locale avec les outils système.

Vérifier les API et leur disponibilité avant de fixer la version
minimale de macOS.

Ne pas demander de permissions d’accessibilité ou d’accès complet
au disque sans besoin technique démontré.

## 4. Découverte et identification des disques

Distinguer :
- Disques physiques externes.
- Volumes et partitions appartenant au même disque.
- Images disque montées.
- Disques internes et volumes système.
- Partages réseau, exclus du périmètre initial.

Présenter une seule cible d’éjection par disque physique.
Un disque contenant plusieurs volumes ne doit pas apparaître
comme plusieurs périphériques indépendants à débrancher.

Ne pas utiliser comme identifiant persistant :
- Le nom affiché.
- Le chemin de montage.
- Le numéro BSD seul, tel que disk4.

Déterminer une stratégie d’identité à partir des métadonnées
réellement disponibles : UUID et identifiants matériels pertinents.

Tester cette stratégie avec APFS et les boîtiers USB.
En cas d’identité absente, dupliquée ou ambiguë, ne pas sélectionner
automatiquement un disque sur la seule base de son nom.

Pour les images disque :
- Identifier les images réellement montées.
- Ne pas se baser uniquement sur une extension ou un nom de volume.
- Regrouper les volumes d’une même image.
- Prévoir un adaptateur utilisant une sortie structurée de hdiutil
  si nécessaire après validation des API disponibles.

## 5. Moteur d’éjection

Séparer la logique système de l’interface.

Pour chaque demande :
1. Capturer la liste des cibles demandées.
2. Revalider leur présence, leur identité et leur admissibilité.
3. Démonter normalement les volumes concernés.
4. Éjecter le disque physique ou détacher l’image.
5. Attendre le résultat système.
6. Actualiser l’inventaire et présenter le résultat.

Gérer explicitement :
- Disque occupé.
- Sauvegarde en cours.
- Déconnexion pendant l’opération.
- Éjection partielle.
- Erreur système.
- Opération qui tarde à répondre.
- Disque déjà démonté mais toujours connecté.

Ne jamais :
- Forcer l’éjection.
- Tuer un processus.
- Arrêter automatiquement une sauvegarde.
- Afficher une réussite avant confirmation.
- Éjecter un disque interne ou système.

Si un délai est dépassé, afficher un état incertain ou en attente,
sans assimiler ce délai à une réussite.

Traiter les cibles indépendamment pour qu’un disque bloqué
n’empêche pas de rendre compte des autres résultats.

## 6. Organisation du code

Prévoir des modules ou composants simples :

- App : cycle de vie et lancement.
- MenuBarController : icône, gestes et construction du menu.
- DiskInventory : observation et inventaire.
- DiskIdentity : identification persistante.
- EjectionService : opérations système.
- DiskImageService : identification et détachement des images.
- PreferencesStore : sélection et options.
- LoginItemService : ouverture de session.
- Models : disques, volumes, états et résultats.

Injecter les services système pour tester la logique sans éjecter
de vrais disques.

Éviter les dépendances externes tant qu’un besoin concret
ne les justifie pas.

## 7. Compilation et installation locale

Commencer par inspecter :
- Les instructions du dépôt.
- La version de macOS et l’architecture du Mac.
- Les outils Swift et le SDK macOS disponibles.
- La présence des Command Line Tools ou de Xcode.
- Les conventions Git existantes.

Voie recommandée :
- Swift Package Manager pour compiler.
- Script pour assembler le bundle EjectDock.app.
- Info.plist, icône et identifiant de bundle stable.
- Signature locale adaptée.
- Script d’installation dans le dossier Applications choisi.

Si les capacités retenues rendent un projet Xcode plus pertinent,
documenter la raison et conserver un build automatisable.

Fournir des commandes simples pour :
- Compiler.
- Tester.
- Installer localement.
- Lancer.
- Produire une archive de distribution.

Ne pas désactiver Gatekeeper globalement.

## 8. Distribution Homebrew

Utiliser un tap personnel, sans dépendre d’une acceptation
dans le catalogue officiel Homebrew.

Organisation cible :
- Dépôt de l’application.
- Dépôt homebrew-tools.
- Fichier Casks/ejectdock.rb.
- Release versionnée contenant le ZIP de l’application.

Le cask doit contenir :
- Version explicite.
- URL de téléchargement versionnée.
- SHA-256 de l’archive.
- Nom et description.
- Page du projet.
- Version minimale de macOS.
- Déclaration du bundle à installer.

Installation visée :

brew tap PROPRIETAIRE/tools
brew install --cask ejectdock

Mise à jour :

brew upgrade --cask ejectdock

Désinstallation :

brew uninstall --cask ejectdock

Conserver les préférences lors d’une désinstallation ordinaire.
Réserver leur suppression explicite à une opération de nettoyage.

Ne pas publier de cask contenant une URL fictive ou un checksum
non vérifié.

Si les dépôts ou les releases doivent rester privés, vérifier
l’authentification du téléchargement des archives :
l’accès Git au tap ne suffit pas nécessairement.

## 9. Signature et architectures

Séparer deux circuits :

Développement personnel :
- Compilation locale.
- Signature locale.
- Installation sur le Mac de développement.
- Aucun compte développeur payant nécessaire pour ce circuit.

Distribution téléchargée :
- Signature Developer ID.
- Hardened Runtime selon les exigences Apple.
- Notarisation.
- Agrafage du ticket au bundle avant archivage.
- Vérification de l’archive finale et test de lancement.

Homebrew ne contourne pas les exigences de Gatekeeper.

Sans certificat de distribution, documenter clairement les limites.
Ne pas intégrer de contournement automatique de sécurité au cask.

Commencer avec l’architecture du Mac de développement.
Pour distribuer sur Intel et Apple Silicon, choisir ensuite :
- Un bundle universel.
- Ou deux archives avec URL et checksum par architecture.

## 10. Automatisation des releases

Après validation du build local :

- Exécuter les tests dans une CI macOS.
- Compiler une release à partir d’un tag versionné.
- Vérifier la cohérence entre tag et version du bundle.
- Signer et notariser si les identifiants sont configurés.
- Produire le ZIP et son SHA-256.
- Publier la release.
- Mettre à jour le cask avec la version et le checksum exacts.

Limiter les permissions des workflows.
Ne pas exposer les certificats ou secrets dans les logs.

La création des dépôts distants, la publication et la configuration
des secrets constituent une étape distincte du développement local.

## 11. Validation

Tests automatisés ciblés :
- Sélection persistante.
- Deux disques portant le même nom.
- Identité ambiguë ou modifiée.
- Regroupement des volumes par disque.
- Exclusion des disques internes et système.
- Déconnexion pendant une opération.
- Échec partiel.
- Clics répétés.
- Aucune cible connectée.
- Reconnaissance et regroupement des images disque.

Tests manuels :
- Clic gauche, clic droit et Option + clic.
- Disque externe avec un volume.
- Disque externe avec plusieurs volumes, si disponible.
- Plusieurs disques, dont un seul sélectionné.
- Plusieurs images disque montées.
- Disque occupé et sauvegarde en cours.
- Débranchement et rebranchement.
- Redémarrage de l’application.
- Ouverture de session.
- Installation, mise à jour et désinstallation Homebrew.
- Conservation des préférences pendant une mise à jour.

Utiliser d’abord des images disque temporaires et des supports
de test. Ne pas interrompre une sauvegarde réelle pour un test.

Indiquer les scénarios non testés faute de matériel.

## 12. Ordre d’implémentation

Phase 1 : socle
- Initialiser le projet.
- Obtenir un build reproductible.
- Afficher l’icône et son menu.
- Valider les gestes souris.
- Afficher l’inventaire en lecture seule.

Phase 2 : fonction principale
- Identifier les disques.
- Persister la sélection.
- Implémenter l’éjection normale.
- Ajouter les états et les erreurs.
- Valider sur un support de test.

Phase 3 : fonctions complémentaires
- Éjecter toutes les images disque.
- Éjecter tous les disques externes.
- Ajouter les réglages et le lancement à la connexion.
- Vérifier l’accessibilité.

Phase 4 : installation locale
- Assembler le bundle.
- Ajouter les scripts de build et d’installation.
- Vérifier le fonctionnement de l’application installée.

Phase 5 : distribution
- Préparer le tap et le cask.
- Configurer les releases.
- Ajouter signature et notarisation selon les moyens disponibles.
- Tester une installation Homebrew complète.

## 13. Critères de réussite

- Un clic éjecte uniquement les cibles configurées.
- Le clic droit et Option + clic ouvrent le menu.
- La sélection survit aux redémarrages et reconnexions.
- Toutes les images disque peuvent être éjectées par une action dédiée.
- Aucun disque interne ou système n’est ciblé.
- Un disque occupé produit un résultat explicite sans forçage.
- Les succès partiels sont distingués des succès complets.
- L’application reste réactive pendant les opérations.
- L’installation et la mise à jour Homebrew sont reproductibles.
- Les limites de validation sont documentées.

## 14. Consignes de travail

Commencer par l’inspection du projet et de l’environnement,
puis implémenter progressivement.

Prendre les décisions techniques courantes de manière autonome.
Ne demander que les informations réellement bloquantes.

Ne pas éjecter le disque de sauvegarde réel de l’utilisateur
sans son accord explicite pour le test.

Respecter les instructions locales et les conventions Git.
Ne jamais utiliser le caractère em dash.
Ne pas ajouter de Co-Authored-By ni de mention de génération
automatique dans les commits, le code ou la documentation.

À chaque étape, distinguer :
- Ce qui est implémenté.
- Ce qui est testé.
- Ce qui reste à vérifier.
- Ce qui dépend d’un accès, certificat ou matériel externe.