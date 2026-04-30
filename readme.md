# 🛠️ IpConfigurator

**IpConfigurator** est un outil graphique développé en PowerShell (Windows Forms) permettant de consulter et de modifier rapidement la configuration réseau IPv4 d'une interface Windows.

## 📝 Description

Cet utilitaire offre une interface simple pour gérer vos paramètres réseau sans passer par les menus complexes de Windows ou la ligne de commande. Il est idéal pour les administrateurs système ou les développeurs ayant besoin de basculer fréquemment entre des configurations statiques et dynamiques.

## ✨ Fonctionnalités

*   **Gestion des interfaces :** Liste uniquement les cartes réseau physiques actives.
*   **Lecture en temps réel :** Affiche le mode (DHCP/Statique), l'adresse IPv4, le préfixe CIDR, la passerelle et les serveurs DNS.
*   **Configuration flexible :**
    *   Bascule instantanée en mode **DHCP**.
    *   Configuration d'adresses **statiques** (IP, préfixe, passerelle optionnelle).
    *   Gestion des **DNS** (0, 1 ou 2 serveurs, ou mode automatique).
*   **Utilitaires :** Bouton de rafraîchissement, fonction "Effacer" les champs et fermeture rapide.

## ⚠️ Limitations connues

*   Support exclusif de l'**IPv4**.
*   Validation simplifiée : le script vérifie le préfixe CIDR (0 à 32), mais n'effectue pas de validation avancée du format des chaînes IP/DNS.
*   **Droits Administrateur :** Requis pour l'application des modifications réseau.

## 🚀 Prerequis

*   **Système :** Windows avec PowerShell 5.1 ou supérieur.
*   **Modules :** Cmdlets `NetTCPIP` (inclus par défaut sur Windows 10/11).
*   **Privilèges :** Exécution en mode **Administrateur**.

---

## 💻 Utilisation

### Option 1 : Script PowerShell
Ouvrez un terminal dans le dossier du projet et lancez :
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\IpConfigurator.ps1
```

### Option 2 : Lanceur Batch
Double-cliquez simplement sur le fichier suivant pour un lancement rapide :
`Lancer_IpConfigurator.bat`

---

## 📦 Création d'un exécutable (.exe)
Si vous souhaitez transformer le script en application autonome, vous pouvez utiliser le module `ps2exe`. Un exemple est disponible dans `commande_ps2exe.txt` :

```powershell
# Installation du module
Install-Module ps2exe -Scope CurrentUser

# Génération de l'exécutable
Invoke-PS2EXE .\IpConfigurator.ps1 .\IpConfigurator.exe -title "IpConfigurator" -description "Configurateur d'adressage ip" -company "Nexus Dev" -product "PowerShell Lab" -version "1.0"
```

---

## 📂 Structure du projet

| Fichier | Description |
| :--- | :--- |
| `IpConfigurator.ps1` | Cœur du projet (Interface GUI et logique). |
| `Lancer_IpConfigurator.bat` | Script de lancement rapide. |
| `commande_ps2exe.txt` | Instructions pour la compilation en .exe. |

---

## 👤 Auteur

**Marley Avix**  
