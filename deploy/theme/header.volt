{% if site_info.logo %}
    {% set logo_img = image(site_info.logo,false) %}
{% else %}
    {% set logo_img = image(brand_info.logo) %}
{% endif %}
{% set logo_link = site_info.url ? site_info.url : '/' %}

<div class="logo">
    <a href="{{ logo_link }}" title="{{ brand_info.name }}">
        <span class="police-emblem" aria-hidden="true">
            <svg viewBox="0 0 44 52" xmlns="http://www.w3.org/2000/svg" focusable="false">
                <path d="M22 2 L40 8.5 V26 C40 37 32 45.5 22 50 C12 45.5 4 37 4 26 V8.5 Z"
                      fill="none" stroke="#A8843B" stroke-width="2.2" stroke-linejoin="round"/>
                <path d="M22 6.4 L36.2 11.6 V26 C36.2 34.8 30.1 41.6 22 45.3 C13.9 41.6 7.8 34.8 7.8 26 V11.6 Z"
                      fill="none" stroke="#C8A24A" stroke-width="0.9" stroke-linejoin="round" opacity="0.85"/>
                <polygon points="22,12.3 24.03,17.71 29.8,17.97 25.28,21.57 26.82,27.13 22,23.95 17.18,27.13 18.72,21.57 14.2,17.97 19.97,17.71"
                         fill="#A8843B"/>
                <path d="M13.4 31.6 H30.6" stroke="#A8843B" stroke-width="1.6" stroke-linecap="round" opacity="0.9"/>
                <path d="M15.4 35.4 H28.6" stroke="#A8843B" stroke-width="1.2" stroke-linecap="round" opacity="0.65"/>
            </svg>
        </span>
        <span class="logo-plate">{{ logo_img }}</span>
    </a>
</div>

<div class="top-nav">
    <ul class="layui-nav">
        {% for nav in navs.top %}
            <li class="layui-nav-item">
                <a href="{{ nav.url }}" class="nav-{{ nav.id }}" target="{{ nav.target }}">{{ nav.name }}</a>
                {% if nav.children %}
                    <dl class="layui-nav-child">
                        {% for child in nav.children %}
                            <dd><a href="{{ child.url }}" class="nav-{{ child.id }}" target="{{ child.target }}">{{ child.name }}</a></dd>
                        {% endfor %}
                    </dl>
                {% endif %}
            </li>
        {% endfor %}
    </ul>
</div>

<div class="user">
    <ul class="layui-nav">
        <li class="layui-nav-item">
            <a class="nav-search" href="javascript:" data-url="{{ url({'for':'home.search.index'}) }}"><i class="layui-icon layui-icon-search"></i> 搜索</a>
        </li>
        {% if auth_user.id > 0 %}
            <li class="layui-nav-item">
                <a href="javascript:"><i class="layui-icon layui-icon-add-circle"></i> 发布</a>
                <dl class="layui-nav-child">
                    <dd><a href="{{ url({'for':'home.question.add'}) }}" target="_blank">提问题</a></dd>
                    <dd><a href="{{ url({'for':'home.article.add'}) }}" target="_blank">写文章</a></dd>
                </dl>
            </li>
            <li class="layui-nav-item">
                <a href="{{ url({'for':'home.uc.notifications'}) }}" target="notify"><i class="layui-icon layui-icon-notice"></i> 消息<span id="notify-dot"></span></a>
            </li>
            <li class="layui-nav-item">
                <a href="javascript:">{{ auth_user.name }}</a>
                <dl class="layui-nav-child">
                    <dd><a href="{{ url({'for':'home.user.show','id':auth_user.id}) }}">我的主页</a></dd>
                    {% if auth_user.edu_role == 2 %}
                        <dd><a href="{{ url({'for':'home.tc.index'}) }}">教学中心</a></dd>
                    {% endif %}
                    <dd><a href="{{ url({'for':'home.uc.index'}) }}">用户中心</a></dd>
                    <dd><a href="{{ url({'for':'home.forum_login.logout'}) }}">退出登录</a></dd>
                </dl>
            </li>
        {% else %}
            <li class="layui-nav-item">
                <a href="{{ url({'for':'home.forum_login.show'}) }}">登录</a>
            </li>
        {% endif %}
    </ul>
</div>
