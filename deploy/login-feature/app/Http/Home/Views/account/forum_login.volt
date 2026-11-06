{% extends 'templates/main.volt' %}

{% block content %}

<div class="wrap" style="max-width:460px;margin:70px auto 110px;">

    <div style="border:1px solid #e6e6e6;border-radius:6px;padding:32px 28px;background:#fff;">

        <h3 style="margin:0 0 6px;font-size:20px;">论坛账号登录</h3>

        <p style="color:#888;margin:0 0 22px;font-size:13px;line-height:1.6;">
            使用警院论坛账号直接登录，无需另行注册。本平台不保存你的论坛密码。
        </p>

        {% if error_message %}
        <div style="background:#fff2f0;border:1px solid #ffccc7;color:#a8071a;padding:9px 12px;border-radius:4px;margin-bottom:16px;font-size:13px;line-height:1.6;">
            {{ error_message }}
        </div>
        {% endif %}

        {% if forum_login_enabled %}

        <form method="post" action="/account/forum/login" autocomplete="off">

            {# 基类 beforeExecuteRoute 对非安全请求强制校验 CSRF 与同源 Referer，
               白名单为空。原生表单无法带 X-Csrf-Token 头，用隐藏字段走
               SecurityValidator 的 postToken 分支，与项目既有约定一致。 #}
            <input type="hidden" name="csrf_token" value="{{ csrfToken.getToken() }}">

            {# 回跳地址：由「个人中心未登录跳转」带上，登录成功后原路返回。
               控制器已按 sanitizeRedirect 消毒，这里仍做 HTML 转义。 #}
            <input type="hidden" name="redirect" value="{{ redirect_url }}">

            <div style="margin-bottom:14px;">
                <input type="text" name="account" value="{{ posted_account }}"
                       placeholder="论坛用户名或邮箱" required maxlength="100"
                       style="width:100%;height:40px;border:1px solid #dcdfe6;border-radius:4px;padding:0 12px;box-sizing:border-box;font-size:14px;">
            </div>

            <div style="margin-bottom:22px;">
                <input type="password" name="password"
                       placeholder="论坛密码（8-32 位）" required minlength="8" maxlength="32"
                       style="width:100%;height:40px;border:1px solid #dcdfe6;border-radius:4px;padding:0 12px;box-sizing:border-box;font-size:14px;">
            </div>

            <button type="submit"
                    style="width:100%;height:40px;background:#1e9fff;color:#fff;border:0;border-radius:4px;font-size:15px;cursor:pointer;">
                登录
            </button>

        </form>

        {% else %}

        <div style="color:#888;font-size:13px;">
            尚未启用论坛账号登录（未配置网关应用密钥）。
        </div>

        {% endif %}

    </div>

</div>

{% endblock %}
