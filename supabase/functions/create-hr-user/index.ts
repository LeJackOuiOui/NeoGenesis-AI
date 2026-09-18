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

    const { name, email, phone, position, role, password, status } = await request.json();
    if (!name || !email || !position || !role || !password || password.length < 6) {
      return json({ error: 'Datos de registro incompletos' }, 400);
    }

    const allowedStatuses = ['Activo', 'En Vacaciones', 'Inactivo'];
    const normalizedStatus = allowedStatuses.includes(status) ? status : 'Activo';

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

    const { error: rpcError } = await adminClient.rpc('create_hr_person', {
      p_user_id: authData.user.id,
      p_full_name: name.trim(),
      p_phone: phone?.trim() ?? '',
      p_position: position.trim(),
      p_role: role,
      p_status: normalizedStatus,
      p_avatar_url: null,
    });

    if (rpcError) {
      await adminClient.auth.admin.deleteUser(authData.user.id);
      return json({ error: rpcError.message }, 400);
    }

    const { error: emailError } = await adminClient
      .from('profiles')
      .update({ email: normalizedEmail })
      .eq('id', authData.user.id);

    if (emailError) {
      await adminClient.auth.admin.deleteUser(authData.user.id);
      return json({ error: emailError.message }, 400);
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

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
