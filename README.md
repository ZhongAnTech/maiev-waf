za\_resty\_waf
===
众安开源waf引擎

简介
===
基于OpenResty®实现的高性能应用防火墙（WAF），需搭配众安开源waf控制台项目一起使用。

特性
===
  * 每个host可使用独立规则集，自定义防护策略，互不干扰
  * 支持对request进行过滤，全http实体字段过滤，包括上传文件
  * 支持对响应头过滤
  * 支持响应体过滤
  * 解决了传统Resty WAF参数个数超100个的绕过攻击
  * 支持白名单，黑名单
  * IPv6支持

状态
===
截止2019年底已在众安生产环境部署使用3年。

版本
===
v4.0

安装
===
  * 1. 安装OpenResty (>= 1.11.2.4) ，参照官方安装文档安装即可。由于规则可能大量涉及到正则匹配的操作，启用pcre-jit总能让性能更好，前提是操作系统支持。
  > ./configure --with-pcre-jit
  * 2. 克隆仓库
  > git clone https://github.com/luxiao/za_resty_waf.git
  * 3. 将包复制到openresty安装目录
  > cp -rf config.json conf lua_scripts /usr/local/openresty/nginx/
  > 请确保nginx用户对该目录/usr/local/openresty/nginx/及子目录有读取权限。
  * 4. 手动编译依赖的动态链接库（libinjection，cjson，ahocorasick）
  进入到对应子仓库目录下，执行Makefile编译对应操作系统平台的动态链接库文件。将编译成功后的so文件拷贝到/usr/local/openresty/lualib下。为方便大家使用，本项目已经预编译好了CentOS7下的所有动态库，放在lua_lib/el7luajit2下。将其拷贝/usr/local/openresty/lualib下即可。
  ```
  lua_lib/el7luajit2
  ├── ahocorasick.so
  ├── cjson.so
  ├── libac.so
  └── libinjection.so
  ```

配置
===
  * lua_scripts/config.lua文件是waf初始化配置文件，包括规则配置文件路径，日志配置。

  * 日志配置支持kafka和syslog两种方式，不建议本地文件的方式，虽然也支持。

  * 规则配置，json格式，参考config.json。除非你对代码很理解，否则不建议手动编辑规则json文件。请使用众安开源的waf控制台项目进行规则创建，自动下发。
  * OpenResty的nginx.conf配置文件http块增加一行引入waf.conf，参考如下：

    ```json
    http {
      ...
      include /usr/local/openresty/nginx/conf/waf.conf;
      ...
      }
    ```

  * 如果任意配置文件(config.lua, config.json, waf.conf)有更新，均需要nginx -s reload重新加载。
    > /usr/local/openresty/bin/openresty -s reload

性能测试
===
以下是在2C1G的阿里云服务器nginx开启8个worker后用Jmeter测试10并发10分钟的结果

| 模式       | 吞吐量（KB/s）   | tps | 95%响应时间ms |
|-----------|-------|-----|--------------|
| 关闭       | 1361 | 7262 | 2 |
| 0条规则    | 777  | 4147 | 4 |
| 10条规则   | 57   | 219  | 103 |

### 结论
可以看出基于nginx的OpenResty性能非常优秀的，waf影响性能的地方在于对http流量的过滤，所以在测试的时候会参考waf关闭和开启时对请求的影响，在10个规则过滤的前提，测试下来的结果是对整个请求影响100ms左右。当然测试结果会随着规则的变化而发生变化，比如规则里开启了对响应体的过滤，则对响应体较大的请求影响比较大。
