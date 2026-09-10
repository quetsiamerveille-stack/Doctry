# DOCTRY

Plateforme intelligente de gestion, perte et retrouvaille de documents d'identité.

Application full-stack : **Flutter** (web + mobile) et **FastAPI** (Python), avec moteur de matching IA (OpenRouter · NVIDIA Nemotron), QR Code natif, séquestre Mobile Money simulé (Orange Money `#150#` / MTN MoMo `*126#`), SMS Textsoft et OTP par email.

---

## 1. Charte graphique

| Rôle | Couleur | Hex |
| --- | --- | --- |
| Bleu Foncé | Textes, en-têtes, boutons sombres | `#1A2B4C` |
| Bleu Siam / Cyan | Identité DOCTRY, actions principales | `#00A8B5` |
| Jaune Or | Mise en avant, récompenses | `#FFD700` |
| Gris | Statut neutre / en attente | `#808080` |
| Rouge | Blocage, perte | `#E53935` |
| Vert | Succès, restitution | `#4CAF50` |

Toutes les icônes proviennent exclusivement de la bibliothèque native Flutter (`Icons.*`). Aucun paquet d'icônes tiers.

---

## 2. Structure des dossiers du projet

```
doctry/
├── backend/                              # API FastAPI
│   ├── app/
│   │   ├── main.py                       # Application, CORS, montage des routers
│   │   ├── config.py                     # Paramètres (pydantic-settings, .env)
│   │   ├── database.py                   # Moteur SQLAlchemy + session
│   │   ├── models.py                     # Modèles ORM (User, Document, LossDeclaration,
│   │   │                                 #   FindDeclaration, MatchResult, Transaction, PaymentAccount,
│   │   │                                 #   Conversation, Message, Notification, Rating, OtpTicket, SmsLog)
│   │   ├── schemas.py                    # Schémas Pydantic (entrées / sorties)
│   │   ├── security.py                   # bcrypt + JWT + dépendances de rôle
│   │   ├── deps.py                       # Dépendances FastAPI réutilisables
│   │   ├── urls.py                       # Construction des URL média
│   │   ├── timeutil.py                   # Utilitaires de dates
│   │   ├── routers/
│   │   │   ├── auth.py                   # status, install, login, signup, OTP, me, profil
│   │   │   ├── documents.py              # pré-enregistrement QR + photo, listing
│   │   │   ├── declarations.py           # pertes, scans, photo, retrouvailles, restitution
│   │   │   ├── payments.py               # recharge, séquestre OM/MTN, libération OTP
│   │   │   ├── chat.py                   # conversations + messages
│   │   │   ├── notifications.py          # cloche de notification
│   │   │   ├── stats.py                  # statistiques propriétaire / trouveur
│   │   │   ├── ratings.py                # notation 5 étoiles tous les 3 jours
│   │   │   ├── admin.py                  # utilisateurs, finance, stats, journal SMS
│   │   │   └── media.py                  # QR Code PNG + images (Bearer ou ?token=)
│   │   └── services/
│   │       ├── qrcode_service.py         # génération QR (lib Python native qrcode)
│   │       ├── deepseek_service.py       # analyse documentaire + floutage (API IA OpenRouter/Nemotron)
│   │       ├── matching_service.py       # comparaison et matching automatique
│   │       ├── payment_service.py        # séquestre Orange Money / MTN MoMo
│   │       ├── otp_service.py            # codes OTP
│   │       ├── email_service.py          # envoi Gmail SMTP (fallback simulation)
│   │       ├── sms_service.py            # Textsoft SMS (fallback journalisé)
│   │       └── notification_service.py   # alertes In-App + SMS
│   ├── storage/                          # base SQLite, QR PNG, photos (créé au runtime)
│   ├── run.py                            # uvicorn 0.0.0.0:8000
│   ├── requirements.txt
│   ├── .env.example
│   ├── smoke_test.py                     # 102 assertions hors-ligne (TestClient)
│   └── live_check.py                     # 52 assertions sur serveur HTTP réel
│
├── lib/                                  # Application Flutter
│   ├── main.dart                         # point d'entrée
│   ├── app.dart                          # MaterialApp, thème, routage par rôle
│   ├── core/
│   │   ├── api/doctry_api.dart           # appels API typés
│   │   ├── config/api_config.dart        # URL du serveur (web / émulateur / réel)
│   │   ├── services/api_client.dart      # HTTP + jeton + mediaUrl
│   │   ├── theme/app_colors.dart         # palette DOCTRY
│   │   ├── theme/app_theme.dart          # ThemeData Material 3
│   │   └── utils/                        # formatters, sélecteur média, sauvegarde
│   │       ├── file_saver.dart           # export conditionnel
│   │       ├── file_saver_web.dart       # téléchargement navigateur
│   │       ├── file_saver_io.dart        # téléchargement mobile/desktop
│   │       ├── file_saver_stub.dart
│   │       ├── media_picker.dart         # galerie / caméra
│   │       └── formatters.dart           # XAF, dates, libellés, statuts
│   ├── models/                           # user, document, declaration, chat, stats, json_helpers
│   ├── providers/                        # auth_provider, workspace_provider, admin_provider
│   ├── screens/
│   │   ├── splash_screen.dart            # icône document Bleu Siam + DOCTRY
│   │   ├── login_screen.dart             # DocTry + « Ravi de vous revoir » + section admin
│   │   ├── signup_screen.dart            # inscription Trouveur / Propriétaire
│   │   ├── otp_screen.dart               # saisie du code OTP email
│   │   ├── install_admin_screen.dart     # création du 1er administrateur (aucun compte par défaut)
│   │   ├── owner/                        # dashboard, accueil, documents, stats, récompense, paiement
│   │   ├── finder/                       # dashboard, accueil, déclaration, scanner QR, stats
│   │   ├── admin/                        # dashboard, accueil, utilisateurs, finance, stats
│   │   └── chat/                         # liste des conversations + fil de discussion
│   └── widgets/                          # brand, common, doctry_shell, doctry_table,
│                                         #   dialogs, match_card, qr_preview, server_config_dialog
│
├── test/widget_test.dart                 # 16 tests (palette, formatters, modèles, écrans responsive)
├── android/                              # permissions caméra/média, label DOCTRY
├── web/                                  # index.html + manifest.json aux couleurs DOCTRY
└── pubspec.yaml
```

---

## 3. Démarrage

### 3.1 Backend FastAPI

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
python run.py
```

L'API démarre sur `http://127.0.0.1:8000`. Documentation interactive : `http://127.0.0.1:8000/docs`.

Aucun utilisateur n'est codé en dur. Au premier lancement, `GET /api/auth/status` renvoie `admin_install_required: true` et l'application Flutter affiche l'écran de création du premier administrateur.

Variables utiles dans `.env` :

| Variable | Rôle |
| --- | --- |
| `DEEPSEEK_API_KEY` | Clé OpenRouter pour l'IA réelle (`nvidia/nemotron-3-ultra-550b-a55b:free`). Vide = moteur heuristique local |
| `SMTP_HOST` / `SMTP_USER` / `SMTP_PASSWORD` | Envoi réel des OTP par Gmail. Vide = simulation, le code est renvoyé dans `dev_code` |
| `TEXTSOFT_API_URL` / `TEXTSOFT_API_KEY` | Envoi réel des SMS. Vide = journalisé et consultable dans l'admin |
| `MIN_REWARD_AMOUNT` | Récompense minimum, 1500 XAF |
| `PLATFORM_COMMISSION_RATE` | Commission plateforme, 0.05 |
| `RATING_INTERVAL_DAYS` | Fréquence du pop-up de notation, 3 jours |
| `CORS_ORIGINS` | `*` par défaut |

### 3.2 Application Flutter

**Web**

```powershell
flutter pub get
flutter run -d chrome
```

**Mobile Android**

```powershell
flutter run -d <device-id>
```

**APK**

```powershell
flutter build apk --debug
flutter build apk --release
```

### 3.3 Adresse du serveur

L'URL de l'API est résolue automatiquement :

- Web / desktop : `http://127.0.0.1:8000`
- Émulateur Android : `http://10.0.2.2:8000`

Sur un **téléphone physique**, ouvrir le bouton « Serveur » de l'écran de connexion (ou l'icône de configuration) et saisir l'adresse IP LAN de la machine qui exécute FastAPI, par exemple `http://192.168.1.20:8000`. Cette adresse est mémorisée. Elle peut aussi être figée à la compilation :

```powershell
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.20:8000
flutter build web  --dart-define=API_BASE_URL=https://api.doctry.app
```

---

## 4. Parcours fonctionnels

### 4.1 Authentification
1. Splash → Connexion (menu déroulant Trouveur / Propriétaire, email, mot de passe).
2. Envoi d'un OTP par email → saisie → redirection vers le dashboard du rôle.
3. Bas de page : « Se connecter en tant qu'admin ».
4. Pas de compte → écran d'inscription.

### 4.2 Propriétaire
- **Document → Par QR code** : Type, Nom, Prénom, Téléphone, Email → « Générer » → QR produit par FastAPI + « Télécharger ».
- **Document → Par photo** : « Exporter depuis la galerie » ou « Filmer ».
- **Déclarer une perte** : tableau à 6 colonnes. Le badge gris « Perdu » passe au bleu au clic, puis « Associer une récompense » (minimum 1500 XAF) → simulateur Orange Money / MTN avec saisie du code PIN → fonds bloqués sur le compte de la plateforme.
- **Document non pré-enregistré** : bouton « Formulaire » sous le tableau (N°, Type, Date, Description) puis même procédure de récompense.
- **Chat** : « Commencer une nouvelle conversation » → liste des trouveurs inscrits.
- **Statistiques** : 4 colonnes (pertes, retrouvailles, restitués, en attente).
- **Envoyer la récompense** : OTP par email → libération du séquestre vers le trouveur, commission plateforme prélevée.

### 4.3 Trouveur
- **Déclaration → Scanner** : caméra du téléphone lit le QR Code et envoie les données au backend.
- **Déclaration → Photo** : galerie ou caméra, puis « Déclarer retrouvaille ».
- **Chat** : « Conversation » → liste des propriétaires.
- **Statistiques** : 4 colonnes.

### 4.4 Administrateur
- **Gestion des utilisateurs** : recherche, création, « Bloquer » / « Débloquer ».
- **Finance** : recherche par date → « Rechercher » ; tableau à 2 colonnes (Revenus Annuels, Revenus Mensuels) + détail des transactions.
- **Statistiques** : 4 colonnes (Pertes Nom & Date, Retrouvailles Nom & Date, Restitutions Date/Lieu/Acteurs, En attente de matching).

### 4.5 Moteur de matching IA
À chaque déclaration de perte ou de retrouvaille :
1. L'IA (OpenRouter · NVIDIA Nemotron) analyse le document (texte + visuel) et floute automatiquement les zones sensibles.
2. Comparaison algorithmique avec l'ensemble des documents en base.
3. **Positif** : alerte « Document similaire trouvé », notification In-App + SMS Textsoft aux deux parties, mise en relation via le chat interne.
4. **Négatif** : notification « Aucune correspondance trouvée », statut « En attente ».

### 4.6 Notation automatique
Tous les 3 jours, un pop-up d'évaluation 5 étoiles s'affiche pour l'utilisateur actif.

---

## 5. Tests

```powershell
# Backend hors-ligne (TestClient)
cd backend; .\.venv\Scripts\python.exe smoke_test.py

# Backend sur serveur HTTP réel
.\.venv\Scripts\python.exe live_check.py http://127.0.0.1:8000

# Flutter
cd ..; flutter analyze; flutter test
```

| Suite | Résultat |
| --- | --- |
| `backend/smoke_test.py` | 102 assertions, 0 échec |
| `backend/live_check.py` | 52 assertions HTTP réelles, 0 échec |
| `flutter analyze` | Aucun problème |
| `flutter test` | 17 tests, 0 échec |
| `flutter build web --release` | OK (24 Mo, `build/web/`) |

> **Note APK** : la compilation Android (`flutter build apk`) nécessite le SDK Android + JDK installés (`ANDROID_HOME`, `JAVA_HOME`). Sur un poste sans SDK, `flutter doctor` signale « Unable to locate Android SDK » ; le build web reste pleinement opérationnel. Le projet est néanmoins configuré pour Android (permissions, `applicationId com.doctry.app`, Gradle 8.14).

Le parcours `live_check.py` couvre de bout en bout : installation de l'admin sans compte par défaut, OTP, inscription des deux rôles, génération et lecture du QR PNG, scan → matching, perte → recharge → séquestre → restitution → libération OTP (commission 250 XAF, net trouveur 4750 XAF pour une récompense de 5000 XAF), chat, notifications, statistiques, notation, blocage/déblocage, finance annuelle/mensuelle/par date, journal SMS et isolation des rôles (401/403).

---

## 6. Responsive

L'interface s'adapte automatiquement :

| Largeur | Navigation | Tableaux |
| --- | --- | --- |
| < 820 px (mobile) | Barre inférieure `NavigationBar` | Cartes empilées |
| ≥ 820 px | Tableaux complets | Colonnes réelles |
| ≥ 900 px (web/tablette) | Rail latéral | Grilles de 4 tuiles |

Les 17 tests Flutter vérifient chaque écran d'authentification et chaque page de tableau de bord à 360×740, 820×1180 et 1440×900 sans aucun débordement de mise en page.

---

## 7. Mise en production

### 7.1 Checklist avant mise en ligne

1. **Clé JWT** : remplacer `JWT_SECRET` dans `backend/.env` par une clé aléatoire longue (`python -c "import secrets; print(secrets.token_hex(32))"`). Ne jamais garder la valeur de développement en production.
2. **`ENVIRONMENT=production`** : désactive le rechargement à chaud d'uvicorn (`reload=False`).
3. **CORS** : remplacer `CORS_ORIGINS=*` par la/les URL exactes du frontend (ex. `https://doctry.app`).
4. **Secrets réels** : renseigner `DEEPSEEK_API_KEY`, `SMTP_*`, `TEXTSOFT_*` pour activer respectivement le matching IA réel, l'envoi OTP par Gmail et les SMS. À vide, tout fonctionne en mode simulation (codes renvoyés dans `dev_code`, SMS journalisés consultables dans l'admin).
5. **Reverse proxy HTTPS** : servir l'API derrière Nginx/Caddy avec TLS (recommandé pour les apps mobiles ; l'APK autorise le HTTP clair via `usesCleartextTraffic` uniquement pour les phases de test LAN).

### 7.2 Démarrage production

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
copy .env.example .env   # puis éditer les valeurs ci-dessus
python run.py            # uvicorn 0.0.0.0:8000, sans reload en production
```

Le frontend web compilé (`build/web/`) est statique : le déployer sur n'importe quel hébergeur statique (Nginx, Firebase Hosting, Vercel) en figeant l'URL de l'API :

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://api.doctry.app
```
