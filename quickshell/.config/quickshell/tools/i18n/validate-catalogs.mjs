#!/usr/bin/env node

import { readdir, readFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";

const projectRoot = resolve(import.meta.dirname, "../..");
const localesRoot = resolve(projectRoot, "locales");
const languages = ["en_US", "zh_CN"];

/**
 * 将嵌套语言包转换为可比较的点分隔键
 * @param {object} value 语言包对象
 * @param {string} prefix 当前键前缀
 * @returns {string[]} 排序后的翻译键
 */
function flattenKeys(value, prefix = "") {
    const keys = [];
    for (const [name, entry] of Object.entries(value)) {
        const key = prefix ? `${prefix}.${name}` : name;
        if (entry && typeof entry === "object" && !Array.isArray(entry)) {
            keys.push(...flattenKeys(entry, key));
        } else {
            keys.push(key);
        }
    }
    return keys.sort();
}

/**
 * 读取并解析语言包
 * @param {string} language 语言代码
 * @param {string} filename 文件名
 * @returns {Promise<object>} 语言包对象
 */
async function readCatalog(language, filename) {
    const path = resolve(localesRoot, language, filename);
    return JSON.parse(await readFile(path, "utf8"));
}

/**
 * 校验两种语言的文件和翻译键完全一致
 * @returns {Promise<void>}
 */
async function validate() {
    const fileSets = await Promise.all(
        languages.map(async language => (await readdir(resolve(localesRoot, language))).filter(name => name.endsWith(".json")).sort())
    );

    if (JSON.stringify(fileSets[0]) !== JSON.stringify(fileSets[1])) {
        throw new Error(`语言包文件不一致: ${JSON.stringify(fileSets)}`);
    }

    for (const filename of fileSets[0]) {
        const catalogs = await Promise.all(languages.map(language => readCatalog(language, filename)));
        const keySets = catalogs.map(catalog => flattenKeys(catalog));
        if (JSON.stringify(keySets[0]) !== JSON.stringify(keySets[1])) {
            throw new Error(`${filename} 的翻译键不一致`);
        }
    }

    console.info(`已校验 ${fileSets[0].length} 组语言包`);
}

validate().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
});
