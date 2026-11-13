import file from '@system.file';
import { defaultProfile } from './engine.js';

/**
 * Хранилище на часах (@system.file, JSON во внутренней памяти приложения):
 *  profile.json — профиль и настройки
 *  session.json — кэш текущей тренировки (восстановление после перезапуска).
 * История тренировок не хранится: после «Готово» на итоге кэш удаляется.
 */
const DIR = 'internal://app/';

const state = {
  profile: defaultProfile(),
  session: null
};

let readyPromise = null;
const writeChains = {};

function readJson(name, fallback) {
  return new Promise((resolve) => {
    file.readText({
      uri: DIR + name,
      success: (data) => {
        try {
          resolve(JSON.parse(data.text));
        } catch (e) {
          resolve(fallback);
        }
      },
      fail: () => resolve(fallback)
    });
  });
}

function chain(name, job) {
  const prev = writeChains[name] || Promise.resolve();
  const next = prev.then(() => new Promise(job));
  writeChains[name] = next;
  return next;
}

function writeJson(name, value) {
  const text = JSON.stringify(value);
  return chain(name, (resolve) => {
    file.writeText({
      uri: DIR + name,
      text: text,
      success: () => resolve(),
      fail: (data, code) => {
        console.error('IronPulse store: write ' + name + ' failed ' + code);
        resolve();
      }
    });
  });
}

function removeFile(name) {
  return chain(name, (resolve) => {
    file.delete({ uri: DIR + name, success: () => resolve(), fail: () => resolve() });
  });
}

export default {
  ready() {
    if (readyPromise === null) {
      readyPromise = Promise.all([
        readJson('profile.json', null),
        readJson('session.json', null)
      ]).then((r) => {
        state.profile = Object.assign(defaultProfile(), r[0] || {});
        state.session = r[1];
      });
      // Данные v1 больше не нужны.
      removeFile('history.json');
      removeFile('weights.json');
    }
    return readyPromise;
  },

  profile() {
    return state.profile;
  },

  saveProfile(p) {
    state.profile = Object.assign(defaultProfile(), p);
    return writeJson('profile.json', state.profile);
  },

  cachedSession() {
    return state.session;
  },

  saveSession(s) {
    state.session = s;
    writeJson('session.json', s);
  },

  clearSession() {
    state.session = null;
    removeFile('session.json');
  }
};
