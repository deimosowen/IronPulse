// Script for compiling build behavior. It is built in the build plug-in and cannot be modified currently.
export { legacyHapTasks } from '@ohos/hvigor-ohos-plugin';

/*
 * IronPulse: подменяем сгенерированную Android-оболочку (shell-activity) своей —
 * entry/shell/MainAbilityShellActivity.java блокирует сворачивание во время тренировки.
 * Задача встаёт между GenerateShellJavaFiles и CompileShellJavaWithJavac.
 */
const path = require('path');
const fs = require('fs');
const { getHvigorNode } = require('@ohos/hvigor');

const node = getHvigorNode(__filename);
const SRC = path.resolve(__dirname, 'shell', 'MainAbilityShellActivity.java');
const DST = path.resolve(__dirname, 'build', 'default', 'intermediates', 'shell', 'default', 'src', 'main',
  'java', 'com', 'ironpulse', 'watch', 'MainAbilityShellActivity.java');

if (node) {
  node.afterEvaluate(() => {
    const compile = node.getTaskByName('default@CompileShellJavaWithJavac');
    const generate = node.getTaskByName('default@GenerateShellJavaFiles');
    if (!compile || !generate) {
      console.warn('IronPulse: shell tasks not found, shell activity is not patched');
      return;
    }
    const patch = node.task(() => {
      fs.mkdirSync(path.dirname(DST), { recursive: true });
      fs.copyFileSync(SRC, DST);
      console.info('IronPulse: shell activity patched');
    }, { name: 'patchShellActivity' });
    patch.dependsOn(generate);
    compile.dependsOn(patch);
  });
}
