# 🌍 Blog Turístico – Flutter + Supabase

Una aplicación móvil desarrollada con Flutter que permite a los usuarios explorar y publicar reseñas sobre sitios turísticos. Utiliza **Supabase** como backend completo: autenticación, base de datos y almacenamiento de archivos.

---

## 🚀 Funcionalidades principales

### 👥 Autenticación de usuarios
- Registro e inicio de sesión de usuarios.
- Gestión de sesiones con Supabase Auth.

### 🧑‍💼 Roles de usuario
- **Visitante**: Puede leer reseñas y dejar comentarios.
- **Publicador**: Puede además crear nuevas reseñas.


### 📝 Publicación de entradas
- Publicadores pueden redactar entradas tipo blog o microblog sobre sitios turísticos.
- Soporte para campos como lugar, descripción, coordenadas y fotografías.


### 📸 Subida de imágenes
- Se pueden seleccionar múltiples imágenes desde el almacenamiento local.
- Se permite únicamente la subida de imágenes de hasta **2MB**.
- Las imágenes son almacenadas en un bucket de Supabase Storage.


---

## 🧰 Tecnologías utilizadas

- **Flutter** – Framework para la app móvil.
- **Supabase** – Backend completo (Auth, DB, Storage).

---


## Permisos de la aplicación
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />


