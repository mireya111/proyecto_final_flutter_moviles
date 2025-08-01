# GeoTopo

**GeoTopo** es una aplicación móvil diseñada para gestionar proyectos topográficos de manera colaborativa. Los usuarios pueden crear proyectos, visualizar áreas y propiedades, colaborar con otros usuarios, compartir ubicaciones en tiempo real y generar capturas del mapa con los datos del proyecto.

---
## Contribuidores
- Anthony Astudillo
- Cabrera Paul
- García Mireya
- Torres Mateo
---
## Evidencias
<img width="738" height="1600" alt="image" src="https://github.com/user-attachments/assets/846da543-2c63-4457-adc4-da32237f3fb8" />


---
## 📑 Tabla de contenido
- [Características principales](#características-principales)
- [Librerías utilizadas](#librerías-utilizadas-y-su-propósito)
- [Permisos requeridos](#permisos-requeridos)
- [Cómo clonar y configurar el proyecto](#cómo-clonar-y-configurar-el-proyecto)
- [Notas importantes](#notas-importantes)
---

## **Características principales**
- **Gestión de proyectos topográficos**: Crea y administra proyectos con detalles como nombre, descripción, área y tipo de figura.
- **Colaboración en tiempo real**: Invita a otros usuarios a colaborar en proyectos y comparte ubicaciones en tiempo real.
- **Visualización de mapas**: Dibuja polígonos, líneas y puntos en un mapa interactivo utilizando Google Maps.
- **Captura de mapas**: Genera capturas del mapa con el área y las líneas dibujadas, ajustando automáticamente el zoom y el punto central.
- **Rastreo de ubicación**: Rastrea y actualiza la ubicación del usuario en segundo plano.

---

## **Librerías utilizadas y su propósito**

### **Dependencias principales**
1. **`supabase_flutter`**:
   - Se utiliza para la autenticación y la gestión de datos en tiempo real.
   - Permite interactuar con la base de datos y el almacenamiento de Supabase.

2. **`flutter_dotenv`**:
   - Carga las variables de entorno desde un archivo `.env` para gestionar credenciales sensibles como las claves de Supabase.

3. **`google_maps_flutter`**:
   - Proporciona la funcionalidad de mapas interactivos para dibujar polígonos, líneas y puntos.

4. **`geolocator`**:
   - Permite obtener la ubicación del usuario y rastrearla en tiempo real.

5. **`flutter_foreground_task`**:
   - Habilita el rastreo de ubicación en segundo plano mediante un servicio en primer plano.

6. **`permission_handler`**:
   - Gestiona los permisos necesarios para la aplicación, como los de ubicación y servicios en segundo plano.

7. **`intl`**:
   - Se utiliza para formatear fechas y otros datos relacionados con la localización.

8. **`location`**:
   - Proporciona servicios de ubicación en tiempo real y configuraciones avanzadas.

9. **`device_info_plus`**:
   - Permite obtener información del dispositivo, como la versión de Android, para gestionar configuraciones específicas.

10. **`android_intent_plus`**:
    - Facilita la interacción con configuraciones del sistema Android, como la optimización de batería.

---

## **Permisos requeridos**

La aplicación requiere los siguientes permisos en Android:

1. **Permisos de ubicación**:
   - `ACCESS_FINE_LOCATION`: Para obtener la ubicación precisa del usuario.
   - `ACCESS_COARSE_LOCATION`: Para obtener la ubicación aproximada.
   - `ACCESS_BACKGROUND_LOCATION`: Para rastrear la ubicación en segundo plano.

2. **Permisos para servicios en primer plano**:
   - `FOREGROUND_SERVICE`: Para ejecutar servicios en primer plano.
   - `WAKE_LOCK`: Para mantener el dispositivo activo mientras se rastrea la ubicación.

3. **Permisos de red**:
   - `INTERNET`: Para interactuar con Supabase y cargar datos.

---

## **Cómo clonar y configurar el proyecto**

### **1. Clonar el repositorio**
Ejecuta el siguiente comando en tu terminal para clonar el repositorio:

```bash
https://github.com/mireya111/proyecto_final_flutter_moviles.git
cd proyecto_final_flutter_moviles
```
### **2. Configurar el archivo `.env`**
El archivo `.env` contiene las credenciales necesarias para interactuar con Supabase. Este archivo se encuentra en la carpeta `assets`.

#### 1. Copia el archivo de ejemplo `.env.example`:

```bash
cp assets/.env.example 
assets/.env
```
#### 2. Abre el archivo assets/.env y reemplaza los valores de SUPABASE_URL y SUPABASE_ANON_KEY con tus credenciales de Supabase.

```environments
SUPABASE_URL=url_Supabase
SUPABASE_ANON_KEY=anon_key_Supabase
```

#### 3. Instalar dependencias

Ejecuta el siguiente comando para instalar las dependencias del proyecto:

```bash
flutter pub get
```

---


## Notas importantes

- 🔋 **Optimización de batería**: Desactívala en Android para permitir el rastreo en segundo plano.
- 📍 **Permisos de ubicación**: Asegúrate de conceder todos los permisos solicitados al instalar la app.
- 🔐 **Archivo `.env`**: No subas este archivo al repositorio. Usa `.gitignore` para evitar filtraciones de claves sensibles.
