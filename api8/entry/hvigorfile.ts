// Script for compiling build behavior. It is built in the build plug-in and cannot be modified currently.
export { legacyHapTasks } from '@ohos/hvigor-ohos-plugin';

/*
 * IronPulse build hooks for the generated Android shell (HarmonyOS 3 runs FA apps inside an APK shell):
 *  1. patchShellActivity — replaces the generated MainAbilityShellActivity.java with entry/shell/…,
 *     which blocks dismissing the app during a workout (GenerateShellJavaFiles → CompileShellJavaWithJavac).
 *  2. patchShellTheme — adds entry/shell/styles.xml and sets it as the activity theme, so the launch
 *     (starting) window is black instead of white (GenerateShellManifest → GenerateShellResource).
 */
const path = require('path');
const fs = require('fs');
const { getHvigorNode } = require('@ohos/hvigor');

const node = getHvigorNode(__filename);
const SHELL_MAIN = path.resolve(__dirname, 'build', 'default', 'intermediates', 'shell', 'default', 'src', 'main');
const ACTIVITY_SRC = path.resolve(__dirname, 'shell', 'MainAbilityShellActivity.java');
const ACTIVITY_DST = path.resolve(SHELL_MAIN, 'java', 'com', 'ironpulse', 'watch', 'MainAbilityShellActivity.java');
const STYLES_SRC = path.resolve(__dirname, 'shell', 'styles.xml');
const STYLES_DST = path.resolve(SHELL_MAIN, 'res', 'values', 'styles.xml');
const MANIFESTS = [path.resolve(SHELL_MAIN, 'AndroidManifest.xml'), path.resolve(SHELL_MAIN, 'cut', 'AndroidManifest.xml')];
const THEME = 'android:theme="@style/IronPulseShellTheme"';

function addTheme(file) {
  if (!fs.existsSync(file)) {
    return;
  }
  let xml = fs.readFileSync(file, 'utf-8');
  if (xml.includes(THEME)) {
    return;
  }
  xml = xml.replace('<activity ', '<activity ' + THEME + ' ');
  fs.writeFileSync(file, xml);
}

if (node) {
  node.afterEvaluate(() => {
    const t = (name) => node.getTaskByName('default@' + name);
    const genJava = t('GenerateShellJavaFiles');
    const compileJava = t('CompileShellJavaWithJavac');
    const genManifest = t('GenerateShellManifest');
    const genRes = t('GenerateShellResource');
    if (!genJava || !compileJava || !genManifest || !genRes) {
      console.warn('IronPulse: shell tasks not found, shell is not patched');
      return;
    }

    const patchActivity = node.task(() => {
      fs.mkdirSync(path.dirname(ACTIVITY_DST), { recursive: true });
      fs.copyFileSync(ACTIVITY_SRC, ACTIVITY_DST);
      console.info('IronPulse: shell activity patched');
    }, { name: 'patchShellActivity' });
    patchActivity.dependsOn(genJava);
    compileJava.dependsOn(patchActivity);

    const patchTheme = node.task(() => {
      fs.mkdirSync(path.dirname(STYLES_DST), { recursive: true });
      fs.copyFileSync(STYLES_SRC, STYLES_DST);
      MANIFESTS.forEach(addTheme);
      console.info('IronPulse: shell theme patched');
    }, { name: 'patchShellTheme' });
    patchTheme.dependsOn(genManifest);
    genRes.dependsOn(patchTheme);
  });
}
