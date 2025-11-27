# Conan Exiles Mod Manager (Microsift & Game Pass)

Un gestor de mods ligero, portátil y potente diseñado específicamente para la versión de **Microsoft Store / Game Pass** de *Conan Exiles*, aunque funciona perfectamente con la versión de Steam.

![Screenshot](https://via.placeholder.com/800x500?text=Captura+del+Gestor+de+Mods) *(Sube una captura real de tu programa aquí)*

## 🚀 Características Principales

* **Descarga Automática:** Baja mods directamente de Steam Workshop sin necesitar el juego en Steam.
* **Game Pass Fix:** Genera automáticamente los archivos `.sig` necesarios para que los mods funcionen en la versión de Microsoft Store.
* **Gestión de Orden:** Reordena la prioridad de carga de tus mods fácilmente.
* **Instalación Dual:** Instala mods en tu Cliente y tu Servidor dedicado simultáneamente.
* **Smart Status:** Detecta qué mods ya tienes instalados y dónde.
* **Portátil:** No requiere instalación, es un solo ejecutable (o script).

## 🛠️ Requisitos

* Windows 10 o 11.
* PowerShell 5.1 o superior (viene instalado en Windows).
* Conexión a internet (para descargar mods).

## 📖 Cómo Usar

1.  **Descarga** la última versión desde [Releases].
2.  Coloca el archivo `.exe` en una carpeta vacía (ej: `Escritorio\ConanMods`).
3.  **Ejecuta** el programa.
4.  Si no detecta tu juego automáticamente, selecciona la carpeta `Content` de tu instalación.
5.  **Descarga Mods:** Pega los IDs o Links de Steam Workshop y pulsa "Descargar".
6.  **Instala:** Selecciona los mods en la lista, ordénalos y pulsa **"INSTALAR EN ORDEN"**.

> **Nota Importante para Game Pass:** Mantén siempre marcada la casilla "Fix Firmas (.sig)" para evitar crasheos al iniciar el juego.

## 🔧 Compilar desde Fuente

Si prefieres ejecutar el script directamente o crear tu propio `.exe`:

1.  Descarga el archivo `ConanModManager.ps1`.
2.  Abre PowerShell como Administrador.
3.  Instala el convertidor (solo una vez): `Install-Module -Name ps2exe`
4.  Compila:
    ```powershell
    Invoke-PS2EXE -InputFile "ConanModManager.ps1" -OutputFile "ConanModManager.exe" -NoConsole -Sta
    ```

## 📄 Licencia

Este proyecto es de código abierto. Siéntete libre de modificarlo y mejorarlo. Da los creditos correspondientes.
Proyecto realizado mediante IA
