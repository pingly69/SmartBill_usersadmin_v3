import { Env, ApiResponse } from './types';
import { AuthService } from './services/auth.service';
import { UserService } from './services/user.service';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // 1. CORS Headers
    const origin = request.headers.get('Origin') || '*';
    const corsHeaders: Record<string, string> = {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
      'Access-Control-Max-Age': '86400',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const json = (data: ApiResponse, status = 200) => {
      return new Response(JSON.stringify(data), {
        status,
        headers: {
          'Content-Type': 'application/json;charset=utf-8',
          ...corsHeaders
        }
      });
    };

    try {
      // 2. Health check route
      if (request.method === 'GET' && path === '/ping') {
        return json({
          success: true,
          message: 'SmartBill Users Admin Worker (Unified D1) is operational.',
          data: { timestamp: new Date().toISOString(), version: '3.1.0-cf' }
        });
      }

      // 3. API Routes: /api or any POST request with action payload
      const isApiRoute = path === '/api' || path.startsWith('/api/') || request.method === 'POST';

      if (isApiRoute) {
        let payload: any = {};
        const contentType = request.headers.get('content-type') || '';

        if (request.method === 'POST') {
          if (contentType.includes('application/json') || contentType.includes('text/plain')) {
            const bodyText = await request.text();
            if (bodyText && bodyText.trim()) {
              try {
                payload = JSON.parse(bodyText);
              } catch (e) {
                return json({ success: false, message: 'Invalid JSON payload format' }, 400);
              }
            }
          }
        }

        const action = payload.action || url.searchParams.get('action');

        if (action) {
          const authService = new AuthService(env);
          const userService = new UserService(env);

          switch (action) {
            case 'verifyPin':
              return json(await authService.verifyPin(payload.pin || url.searchParams.get('pin')));

            case 'registerUser':
              return json(await authService.registerUser(
                payload.pin || payload.matchedPin,
                payload.line_uid || payload.lineUid,
                payload.displayName || payload.line_profile,
                payload.pictureUrl || payload.avatar_url
              ));

            case 'listUsers':
              return json(await userService.listUsers());

            case 'createUser':
              return json(await userService.createUser(payload));

            case 'updateUser':
              return json(await userService.updateUser(payload));

            case 'deleteUser':
              return json(await userService.deleteUser(
                payload.users_id || payload.line_uid || payload.target_line_uid
              ));

            case 'getApprovers':
            case 'listApprovers':
              return json(await userService.getApproversByTag(
                payload.tag || url.searchParams.get('tag') || ''
              ));

            default:
              return json({ success: false, message: `Unknown action: "${action}"` }, 404);
          }
        }

        // Handle GET queries e.g. GET /api?action=listUsers or GET /api?action=getApprovers&tag=คุมวงเงินสด
        if (request.method === 'GET' && path === '/api') {
          const getAction = url.searchParams.get('action');
          const userService = new UserService(env);

          if (getAction === 'listUsers') {
            return json(await userService.listUsers());
          }
          if (getAction === 'getApprovers' || getAction === 'listApprovers') {
            return json(await userService.getApproversByTag(url.searchParams.get('tag') || ''));
          }
        }
      }

      // If ASSETS binding is available (Cloudflare Workers Static Assets), delegate to assets
      if (env.ASSETS) {
        return await env.ASSETS.fetch(request);
      }

      return json({ success: false, message: `Route not found: ${request.method} ${path}` }, 404);

    } catch (err: any) {
      console.error('Worker Uncaught Error:', err);
      return json({
        success: false,
        message: 'Internal Server Error: ' + (err.message || 'Unknown error occurred')
      }, 500);
    }
  }
};
