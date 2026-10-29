# NEOGENESIS IA

Aplicación Flutter conectada a Supabase.

## Asistente interno de RRHH

El asistente responde consultas de empleados usando documentos activos de
`public.hr_knowledge_documents`. Si no puede respaldar una respuesta con una
fuente pertinente, registra la consulta como `waiting_for_hr` y la muestra en
la bandeja **Consultas a RRHH**. Las consultas y las respuestas humanas quedan
guardadas en `public.hr_assistant_interactions`.

### Despliegue

1. Aplica la migración `supabase/migrations/202610290001_create_hr_assistant.sql`.
2. Despliega la función `hr-assistant` con verificación JWT habilitada.
3. Configura `OPENAI_API_KEY` como secreto de Supabase. Opcionalmente, configura
   `OPENAI_MODEL` (por defecto `gpt-4o-mini`). La clave nunca debe incluirse en
   la aplicación Flutter.
4. Agrega documentos internos en `hr_knowledge_documents` con título, área y
   contenido; RRHH puede administrarlos desde Supabase. Solo los documentos
   activos se consideran para las respuestas.

La función permite consultar únicamente a perfiles con rol `Empleado` que no
estén inactivos. RRHH y administradores pueden consultar la bandeja y responder
las preguntas escaladas; cada empleado solo puede leer su propio historial.
