# Space Invaders

Clone de Space Invaders en plusieurs versions.

## SpaceInvaders (Swift/SpriteKit) - Version Native macOS

Application native macOS utilisant SpriteKit pour des performances optimales à 60 FPS.

### Compilation

```bash
cd SpaceInvaders
swiftc -o SpaceInvaders main.swift -framework Cocoa -framework SpriteKit -framework AVFoundation -O
./SpaceInvaders
```

### Contrôles

| Touche | Action |
|--------|--------|
| **← / →** | Déplacer le vaisseau |
| **A / D** | Déplacer le vaisseau (alternatif) |
| **ESPACE** | Tirer |
| **CLIC SOURIS** | Tirer (alternatif) |
| **P** | Pause |
| **M** | Activer/Désactiver la musique |
| **G** | Mode Dieu (immortel + one-shot boss) |
| **K** | Tuer tous les ennemis (mode dieu uniquement) |
| **B** | Aller directement au boss (niveau 5) |
| **O** | Mode Panique (aliens vitesse maximum) |
| **ESC** | Quitter |

### Fonctionnalités

- Animations des aliens style Space Invaders original (2 frames)
- Power-ups : bouclier, tir rapide, tir triple, vie extra, bombe
- Boss tous les 5 niveaux
- Système de combo pour multiplier les points
- Effets sonores synthétisés
- Musique de fond rétro
- Scènettes de transition entre les niveaux
- High score sauvegardé

---

## space2.py - Version Python améliorée

Version Python avec turtle graphics, incluant power-ups et boss.

```bash
python3 space2.py
```

---

## space1.py - Version Python originale

Version basique en Python.

```bash
python3 space1.py
```
