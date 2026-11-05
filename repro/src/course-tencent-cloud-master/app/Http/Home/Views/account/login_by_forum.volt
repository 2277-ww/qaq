<form class="layui-form account-form" method="POST" action="{{ url({'for':'home.account.forum_login'}) }}">
    <div class="layui-form-item">
        <div class="layui-input-wrap">
            <div class="layui-input-prefix"><i class="layui-icon layui-icon-username"></i></div>
            <input id="cf-account" class="layui-input" type="text" name="account" autocomplete="off" placeholder="论坛用户名 / 邮箱" lay-verify="required">
        </div>
    </div>
    <div class="layui-form-item">
        <div class="layui-input-wrap">
            <div class="layui-input-prefix"><i class="layui-icon layui-icon-password"></i></div>
            <input class="layui-input" type="password" name="password" autocomplete="off" placeholder="论坛密码" lay-affix="eye" lay-verify="required">
        </div>
    </div>
    <div class="layui-form-item">
        <div class="layui-input-block">
            <button id="cf-submit-btn" class="layui-btn layui-btn-fluid" lay-submit="true" lay-filter="go">论坛账号登录</button>
            <input type="hidden" name="return_url" value="{{ return_url }}">
        </div>
    </div>
    <div class="layui-form-item">
        <div class="layui-form-mid layui-word-aux">
            使用警院论坛账号登录，无需在本平台重复注册
        </div>
    </div>
</form>
