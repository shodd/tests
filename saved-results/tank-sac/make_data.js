const { readFile, writeFile } = require('node:fs/promises');

async function getData(goal, t) {
    const content = await readFile(`./SAC_${goal}_SP_ML_t${t}.csv`, 'utf-8');
    const [header, ...body] = content.split('\n').map((line) => line.split(',').map((cell) => cell.trim()));
    const probIdx = header.indexOf('prob');
    const probs = body.map((row) => parseFloat(row[probIdx])).sort((a, b) => a - b);
    return probs[Math.floor(probs.length / 2)];
}

async function main() {
    const lines = ['t,max'];
    for (const t of [7, 8, 9, 10, 11, 12, 14, 16, 18, 20]) {
        const max = await getData('MAX', t);
        lines.push(`${t},${max}`);
    }
    const content = lines.join('\n');
    await writeFile('data.csv', content, 'utf-8');
}

main().then(() => console.log('Done!'));
