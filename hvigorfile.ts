import { appTasks, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import type { OhosAppContext } from '@ohos/hvigor-ohos-plugin';
import type { HvigorNode, HvigorPlugin } from '@ohos/hvigor';

/**
 * 根据构建模式自动切换签名配置
 *
 * 策略：
 *   buildMode=debug   -> signingConfig=default（DevEco 自动生成的 debug 证书）
 *   buildMode=release -> signingConfig=release（正式发布证书）
 *
 * 证书未配置时（storeFile 为空）自动跳过，出 unsigned 包，不阻断构建。
 * 这样 DevEco 首次 Run 自动生成 debug 证书前，构建不会因空密码报错。
 *
 * 使用方法：
 *   1. 测试：DevEco Run 时选"自动生成签名"，会填充 default 配置的 material
 *   2. 发布：在 build-profile.json5 的 signingConfigs 里加 release 配置，填入发布凭据
 *   3. 之后 debug/release 构建自动切换对应证书
 */
const DEBUG_SIGNING = 'default';
const RELEASE_SIGNING = 'release';

const autoSwitchSigningPlugin: HvigorPlugin = {
  pluginId: 'auto-switch-signing',
  apply: (node: HvigorNode) => {
    const appCtx = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext | undefined;
    if (!appCtx) {
      return;
    }
    const mode = appCtx.getBuildMode();
    const target = mode === 'debug' ? DEBUG_SIGNING : RELEASE_SIGNING;
    const opt = appCtx.getBuildProfileOpt() as Record<string, Object>;

    // 检查目标签名配置是否已有有效证书（storeFile 非空）
    const appConfig = opt?.['app'] as Record<string, Object> | undefined;
    const configs = (appConfig?.['signingConfigs'] ?? []) as Array<Record<string, Object>>;
    let hasValidCert = false;
    for (const config of configs) {
      if (config['name'] === target) {
        const material = config['material'] as Record<string, string> | undefined;
        if (material && material['storeFile'] && material['storeFile'].length > 0) {
          hasValidCert = true;
        }
        break;
      }
    }

    if (!hasValidCert) {
      console.log(`[auto-signing] buildMode=${mode} -> ${target} cert not configured, build unsigned`);
      return;
    }

    const products = (appConfig?.['products'] ?? []) as Array<Record<string, Object>>;
    let changed = false;
    for (const product of products) {
      if (product['signingConfig'] !== target) {
        product['signingConfig'] = target;
        changed = true;
      }
    }
    if (changed) {
      appCtx.setBuildProfileOpt(opt);
      console.log(`[auto-signing] buildMode=${mode} -> signingConfig=${target}`);
    }
  }
};

export default {
  system: appTasks,
  plugins: [autoSwitchSigningPlugin]
};
