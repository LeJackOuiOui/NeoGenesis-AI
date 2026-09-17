import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const { name, email, position, role, password } = await request.json();
    if (!name || !email || !position || !role || !password || password.length < 6) {
      return json({ error: 'Datos de registro incompletos' }, 400);
    }

    const normalizedEmail = email.toLowerCase().trim();
    if (!normalizedEmail.includes('@') || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) {
      return json({ error: 'El correo institucional no es válido' }, 400);
    }

    const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
      email: normalizedEmail,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: name.trim(),
        position: position.trim(),
        role,
        phone: '',
      },
    });

    if (authError || !authData.user) {
      return json({ error: authError?.message ?? 'No se pudo crear la cuenta' }, 400);
    }

    const profile = {
      id: authData.user.id,
      nombre: name.trim(),
      correo: normalizedEmail,
      telefono: '',
      cargo: position.trim(),
      role,
      estado: 'Activo',
    };

    const { data: savedProfile, error: profileError } = await adminClient
      .from('profiles')
      .upsert(profile)
      .select('id, nombre, correo, cargo, role, estado, created_at')
      .single();

    if (profileError) {
      await adminClient.auth.admin.deleteUser(authData.user.id);
      return json({ error: profileError.message }, 400);
    }

    await adminClient.from('system_logs').insert({
      event: 'user_created',
      description: `Usuario ${profile.correo} creado con rol ${profile.role}`,
      metadata: { user_id: profile.id, role: profile.role },
    });

    return json({ profile: savedProfile });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Error interno' }, 500);
  }
});

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
