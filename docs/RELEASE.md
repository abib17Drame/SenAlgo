# Publier une version

Les paquets sont fabriqués par GitHub Actions (`.github/workflows/release.yml`).
Rien n'est construit à la main.

## Publier

```bash
git tag v1.0.0
git push origin v1.0.0
```

Le tag déclenche le workflow. Il exécute d'abord `flutter analyze` et les
tests ; si l'un des deux échoue, aucun paquet n'est fabriqué. Ensuite trois
machines travaillent en parallèle et la release est créée automatiquement avec
les fichiers attachés.

Compter une dizaine de minutes. Le suivi est dans l'onglet **Actions**.

Pour vérifier que tout compile sans rien publier, lancer le workflow à la main
depuis l'onglet Actions (bouton **Run workflow**) : les paquets sont produits
et téléchargeables comme artefacts, mais aucune release n'est créée.

## Pourquoi Windows passe par GitHub

Flutter ne sait pas compiler pour Windows depuis Linux : il faut la chaîne
d'outils Visual Studio. Ni Docker ni Wine n'y changent rien. GitHub fournit des
machines Windows, c'est la seule voie praticable depuis un poste Linux.

## Signature Android

Sans configuration, l'APK est signé avec la **clé de débogage**. Il s'installe,
mais cette clé est régénérée à chaque exécution du workflow : Android refusera
d'installer une nouvelle version par-dessus l'ancienne, l'utilisateur devra
désinstaller puis réinstaller, et perdra ses données.

Pour signer correctement, créer une clé **une seule fois** :

```bash
keytool -genkey -v -keystore ~/senalgo-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Conserver ce fichier et son mot de passe en lieu sûr et **hors du dépôt** : le
perdre interdit définitivement toute mise à jour de l'application publiée.

Puis l'encoder :

```bash
base64 -w 0 ~/senalgo-upload.jks
```

Enfin, dans **Settings → Secrets and variables → Actions**, créer quatre
secrets :

| Secret | Valeur |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | la sortie de la commande `base64` ci-dessus |
| `ANDROID_STORE_PASSWORD` | mot de passe du fichier de clés |
| `ANDROID_KEY_PASSWORD` | mot de passe de la clé |
| `ANDROID_KEY_ALIAS` | `upload` |

Le workflow les détecte tout seul. Sans eux, il continue de fonctionner et
signale l'avertissement dans le journal d'exécution.

En local, la même chose se fait avec un fichier `android/key.properties`
(ignoré par git) :

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/chemin/absolu/vers/senalgo-upload.jks
```

## Identifiants d'application

Ils sont fixés et **ne doivent plus changer** : les modifier après une
distribution empêcherait toute mise à jour chez les utilisateurs déjà équipés.

| Plateforme | Identifiant | Défini dans |
|---|---|---|
| Android | `io.github.abib17drame.senalgo` | `android/app/build.gradle.kts` |
| Linux | `io.github.abib17drame.SenAlgo` | `linux/CMakeLists.txt` |

Sur Linux, cet identifiant doit rester identique au nom du fichier `.desktop`
dans `linux/packaging/`, sans quoi GNOME n'associe pas la fenêtre à
l'application et affiche une icône générique.

## Numéro de version

Il vient de `pubspec.yaml` :

```yaml
version: 1.0.0+1
```

Le nombre après `+` est le `versionCode` Android : il doit **croître à chaque
publication**, sinon l'installation de la mise à jour est refusée. Le penser à
chaque nouveau tag.
