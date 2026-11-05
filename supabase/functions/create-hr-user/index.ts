import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authorization = request.headers.get('Authorization');

    if (!authorization) {
      return json({ error: 'No autorizado' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceKey);
    const token = authorization.replace('Bearer ', '');
    const { data: callerData } = await adminClient.auth.getUser(token);

    if (!callerData.user) {
      return json({ error: 'Sesión inválida' }, 401);
    }

    const { data: callerProfile } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', callerData.user.id)
      .maybeSingle();

    if (callerProfile?.role !== 'Administrador' && callerProfile?.role !== 'Responsable RRHH') {
      return json({ error: 'No tienes permisos para crear usuarios' }, 403);
    }

    const body = await request.json();
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    const phone = typeof body.phone === 'string' ? body.phone.trim() : '';
    const position = typeof body.position === 'string' ? body.position.trim() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    const fieldErrors: Record<string, string> = {};

    if (name.length < 2 || name.length > 100 ||
        !/^[a-zA-ZÀ-ÖØ-öø-ÿ][a-zA-ZÀ-ÖØ-öø-ÿ .'-]*$/.test(name)) {
      fieldErrors.name = 'Ingresa un nombre válido de entre 2 y 100 caracteres.';
    }
    if (!isValidEmail(email)) {
      fieldErrors.email = 'Ingresa un correo electrónico válido.';
    } else if (!/^[a-z0-9._%+\-]+@(gmail|googlemail)\.com$/.test(email)) {
      fieldErrors.email = 'El correo debe ser de Gmail o Google Mail.';
    }
    if (!phone) {
      fieldErrors.phone = 'Ingresa el teléfono.';
    } else if (!isValidPhone(phone)) {
      fieldErrors.phone = 'El teléfono debe tener entre 7 y 15 dígitos.';
    }
    if (!position || position.length > 100) {
      fieldErrors.position = 'El cargo es obligatorio y no puede superar 100 caracteres.';
    }
    if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
      fieldErrors.password = 'La contraseña debe tener al menos 8 caracteres, una letra y un número.';
    }
    if (Object.keys(fieldErrors).length > 0) {
      return json({
        error: 'Corrige los campos indicados.',
        fieldErrors,
      }, 400);
    }
    const role = 'Empleado';

    const allowedStatuses = ['Activo', 'En Vacaciones', 'Inactivo'];
    const normalizedStatus = 'Activo';

    const normalizedEmail = email;

    const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
      email: normalizedEmail,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: name.trim(),
        position: position.trim(),
        role,
        phone: phone?.trim() ?? '',
      },
    });

    if (authError || !authData.user) {
      return json({ error: authError?.message ?? 'No se pudo crear la cuenta' }, 400);
    }

    const { error: profileError } = await adminClient.from('profiles').upsert({
      id: authData.user.id,
      nombre: name.trim(),
      email: normalizedEmail,
      telefono: phone?.trim() ?? '',
      cargo: position.trim(),
      role,
      estado: normalizedStatus,
    }, { onConflict: 'id' });

    if (profileError) {
      await adminClient.auth.admin.deleteUser(authData.user.id);
      return json({ error: profileError.message }, 400);
    }

    const { data: savedProfile } = await adminClient
      .from('profiles')
      .select('id, nombre, email, cargo, role, estado, created_at')
      .eq('id', authData.user.id)
      .single();

    if (!savedProfile) {
      await adminClient.auth.admin.deleteUser(authData.user.id);
      return json({ error: 'La RPC no devolvió el perfil creado' }, 400);
    }

    const profile = savedProfile;

    await adminClient.from('system_logs').insert({
      event: 'user_created',
      description: `Usuario ${profile.email} creado con rol ${profile.role}`,
      metadata: { user_id: profile.id, role: profile.role },
    });

    return json({ profile: savedProfile });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Error interno' }, 500);
  }
});

function isValidEmail(value: string) {
  if (value.length > 254) return false;
  const [localPart, ...domainParts] = value.split('@');
  if (domainParts.length !== 1 || localPart.length > 64 ||
      localPart.startsWith('.') || localPart.endsWith('.') ||
      localPart.includes('..')) return false;
  return /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/.test(value);
}

function isValidPhone(value: string) {
  if (!/^[0-9+()\- ]+$/.test(value) ||
      (value.indexOf('+') > 0) ||
      (value.indexOf('+') !== value.lastIndexOf('+'))) return false;
  const digits = value.replace(/\D/g, '');
  return digits.length >= 7 && digits.length <= 15;
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
