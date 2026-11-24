<?php
declare(strict_types=1);

/**
 * Excel workbooks (.xlsx), written and read with nothing but zlib and the XML reader that every PHP build has
 * (no ZipArchive, no library).
 *
 * Written: the import templates (an Import sheet with the column names, a How to fill sheet, and drop-down
 * lists of the allowed values and of the company's own sites, customers, items, accounts and the rest) and every
 * list and report exported "to spreadsheet". A workbook keeps its columns whatever program saves it again:
 * Excel, WPS or LibreOffice, on any regional setting, so a filled-in template always comes back the way it went out.
 *
 * Read: Import from CSV takes an .xlsx as well as a CSV. Dates typed as dates, numbers, codes with leading
 * zeros, accented letters and the peso sign come through as they look in the sheet.
 */
final class Xlsx
{
    private const MAX_ROWS = 5000;   // the rows of a template the drop-downs and the text format reach

    // ================================================================== writing

    /**
     * One sheet:
     *   name    sheet tab name
     *   head    the column names (row 1, bold, frozen)
     *   rows    the data rows
     *   kinds   per column: 'text' (kept exactly as typed, codes keep their zeros), 'num', 'date' or 'auto'
     *           ('auto' = numbers become numbers and 2026-09-30 dates become dates; the default)
     *   lists   per column index: ['values' => [...], 'strict' => bool] - a drop-down in that column (template)
     *   widths  per column index: the width in characters (else worked out from the content)
     *   filter  true for a filter on the header row
     *   wrap    true to wrap long text (the How to fill sheet)
     *   hidden  true for a hidden sheet (the lists the drop-downs read)
     *   title   rows above the head: [[text, 'bold'|'note'], ...] (How to fill)
     */
    public static function build(array $sheets): string
    {
        $files = [];
        $listSheet = [];      // values of the drop-downs, one column each, on a hidden sheet
        foreach ($sheets as $i => &$s) {
            $s += ['head' => [], 'rows' => [], 'kinds' => [], 'lists' => [], 'widths' => [], 'filter' => false, 'wrap' => false, 'hidden' => false, 'title' => []];
            foreach ($s['lists'] as $col => $list) {
                $values = array_values(array_unique(array_filter(array_map(fn($v) => trim((string)$v), (array)$list['values']), 'strlen')));
                if (!$values) {
                    unset($s['lists'][$col]);
                    continue;
                }
                $inline = implode(',', $values);
                if (strlen($inline) <= 250 && !preg_match('/[,"]/', implode('', $values))) {
                    $s['lists'][$col]['formula'] = '"' . $inline . '"';
                } else {
                    $listSheet[] = $values;
                    $c = self::colName(count($listSheet) - 1);
                    $s['lists'][$col]['formula'] = 'Lists!$' . $c . '$1:$' . $c . '$' . count($values);
                }
            }
        }
        unset($s);
        if ($listSheet) {
            $rows = [];
            foreach ($listSheet as $c => $values) {
                foreach ($values as $r => $v) {
                    $rows[$r][$c] = $v;
                }
            }
            $max = max(array_map('count', $listSheet));
            $grid = [];
            for ($r = 0; $r < $max; $r++) {
                $line = [];
                for ($c = 0; $c < count($listSheet); $c++) {
                    $line[] = $rows[$r][$c] ?? '';
                }
                $grid[] = $line;
            }
            $sheets[] = ['name' => 'Lists', 'head' => null, 'rows' => $grid, 'kinds' => array_fill(0, count($listSheet), 'text'),
                'lists' => [], 'widths' => [], 'filter' => false, 'wrap' => false, 'hidden' => true, 'title' => []];
        }

        $names = [];
        $sheetXml = [];
        foreach ($sheets as $i => $s) {
            $name = self::sheetName((string)$s['name'], $names);
            $names[] = $name;
            $sheetXml[] = self::sheet($s, $i === 0);
        }

        $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            . '<Default Extension="xml" ContentType="application/xml"/>'
            . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            . '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
            . '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>';
        foreach ($sheetXml as $i => $_) {
            $ct .= '<Override PartName="/xl/worksheets/sheet' . ($i + 1) . '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
        }
        $ct .= '</Types>';
        $files['[Content_Types].xml'] = $ct;
        $files['_rels/.rels'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            . '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
            . '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
            . '</Relationships>';
        $now = gmdate('Y-m-d\TH:i:s\Z');
        $creator = self::x(function_exists('app_name') ? (string)app_name() : 'G-SMaRT Distribution System');
        $files['docProps/core.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" '
            . 'xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            . '<dc:creator>' . $creator . '</dc:creator><cp:lastModifiedBy>' . $creator . '</cp:lastModifiedBy>'
            . '<dcterms:created xsi:type="dcterms:W3CDTF">' . $now . '</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">' . $now . '</dcterms:modified>'
            . '</cp:coreProperties>';
        $files['docProps/app.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>' . $creator . '</Application></Properties>';

        $wb = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            . '<bookViews><workbookView activeTab="0"/></bookViews><sheets>';
        $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
        foreach ($names as $i => $name) {
            $wb .= '<sheet name="' . self::x($name) . '" sheetId="' . ($i + 1) . '"' . (!empty($sheets[$i]['hidden']) ? ' state="hidden"' : '') . ' r:id="rId' . ($i + 1) . '"/>';
            $rels .= '<Relationship Id="rId' . ($i + 1) . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' . ($i + 1) . '.xml"/>';
            $files['xl/worksheets/sheet' . ($i + 1) . '.xml'] = $sheetXml[$i];
        }
        $wb .= '</sheets></workbook>';
        $rels .= '<Relationship Id="rId' . (count($names) + 1) . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
        $files['xl/workbook.xml'] = $wb;
        $files['xl/_rels/workbook.xml.rels'] = $rels;
        $files['xl/styles.xml'] = self::styles();
        return self::zip($files);
    }

    /** Sends a workbook to the browser and stops */
    public static function download(string $filename, array $sheets): never
    {
        $bytes = self::build($sheets);
        $filename = preg_replace('/\.(csv|txt)$/i', '', preg_replace('/[^A-Za-z0-9_.-]/', '_', $filename));
        if (!preg_match('/\.xlsx$/i', $filename)) {
            $filename .= '.xlsx';
        }
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        header('Content-Length: ' . strlen($bytes));
        header('Cache-Control: private, no-store');
        echo $bytes;
        exit;
    }

    // style ids of styles()
    private const S_HEAD = 1, S_TEXT = 2, S_DATE = 3, S_DATETIME = 4, S_WRAP = 5, S_TITLE = 6, S_NOTE = 7, S_NUM = 8, S_AMOUNT = 9;

    private static function styles(): string
    {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            . '<numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy\-mm\-dd"/><numFmt numFmtId="165" formatCode="yyyy\-mm\-dd\ hh:mm"/></numFmts>'
            . '<fonts count="4">'
            . '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
            . '<font><b/><sz val="11"/><color rgb="FF16324F"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
            . '<font><b/><sz val="14"/><color rgb="FF16324F"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
            . '<font><sz val="11"/><color rgb="FF44546A"/><name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
            . '</fonts>'
            . '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
            . '<fill><patternFill patternType="solid"><fgColor rgb="FFE3EBF3"/><bgColor indexed="64"/></patternFill></fill></fills>'
            . '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
            . '<border><left/><right/><top/><bottom style="thin"><color rgb="FF9FB3C8"/></bottom><diagonal/></border></borders>'
            . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
            . '<cellXfs count="10">'
            . '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
            . '<xf numFmtId="49" fontId="1" fillId="2" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
            . '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
            . '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
            . '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
            . '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>'
            . '<xf numFmtId="49" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
            . '<xf numFmtId="49" fontId="3" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>'
            . '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
            . '<xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
            . '</cellXfs>'
            . '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
            . '</styleSheet>';
    }

    private static function sheet(array $s, bool $first): string
    {
        $head = $s['head'];
        $ncol = max(count((array)$head), $s['rows'] ? max(array_map(fn($r) => count((array)$r), $s['rows'])) : 0, 1);
        $kinds = [];
        for ($c = 0; $c < $ncol; $c++) {
            $kinds[$c] = $s['kinds'][$c] ?? 'auto';
        }
        // a column with amounts in it (a number with centavos) shows every number in it as 1,234.50
        for ($c = 0; $c < $ncol; $c++) {
            if ($kinds[$c] !== 'auto') {
                continue;
            }
            foreach (array_slice($s['rows'], 0, 2000) as $r) {
                $v = array_values((array)$r)[$c] ?? null;
                if ((is_float($v) && floor($v) != $v) || (is_string($v) && preg_match('/^-?(0|[1-9]\d{0,14})\.\d{1,10}$/', $v))) {
                    $kinds[$c] = 'amount';
                    break;
                }
            }
        }
        $top = count($s['title']);                    // rows above the head
        $headRow = $head !== null ? $top + 1 : 0;     // 0 = no head row

        // column widths: the longest value seen, within reason
        $widths = [];
        for ($c = 0; $c < $ncol; $c++) {
            $w = $head !== null ? mb_strlen((string)($head[$c] ?? '')) + 3 : 6;
            foreach (array_slice($s['rows'], 0, 400) as $r) {
                $w = max($w, mb_strlen((string)($r[$c] ?? '')) + 2);
            }
            $widths[$c] = (float)($s['widths'][$c] ?? min(max($w, 8), $s['wrap'] ? 70 : 50));
        }

        $x = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            . '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">';
        // printed landscape, as wide as the page
        $x .= '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>';
        $x .= '<sheetViews><sheetView workbookViewId="0"' . ($first ? ' tabSelected="1"' : '') . '>';
        if ($headRow) {
            $x .= '<pane ySplit="' . $headRow . '" topLeftCell="A' . ($headRow + 1) . '" activePane="bottomLeft" state="frozen"/>'
                . '<selection pane="bottomLeft" activeCell="A' . ($headRow + 1) . '" sqref="A' . ($headRow + 1) . '"/>';
        }
        $x .= '</sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>';
        for ($c = 0; $c < $ncol; $c++) {
            // a text column stays text for whatever is typed into it later (codes keep their leading zeros)
            $style = $kinds[$c] === 'text' ? ' style="' . ($s['wrap'] ? self::S_WRAP : self::S_TEXT) . '"' : '';
            $x .= '<col min="' . ($c + 1) . '" max="' . ($c + 1) . '" width="' . round($widths[$c] + 0.7, 2) . '" customWidth="1"' . $style . '/>';
        }
        $x .= '</cols><sheetData>';

        $rowNo = 0;
        foreach ($s['title'] as [$text, $kind]) {
            $rowNo++;
            $lines = $kind === 'note' ? max(1, (int)ceil(mb_strlen((string)$text) / max(40, (int)(array_sum($widths) * 1.05)))) : 1;
            $x .= '<row r="' . $rowNo . '"' . ($kind === 'note' ? ' ht="' . (15 * $lines + 3) . '" customHeight="1"' : ($kind === 'bold' ? ' ht="21" customHeight="1"' : '')) . '>'
                . self::str('A' . $rowNo, (string)$text, $kind === 'bold' ? self::S_TITLE : self::S_NOTE) . '</row>';
        }
        if ($head !== null) {
            $rowNo++;
            $x .= '<row r="' . $rowNo . '" ht="20" customHeight="1">';
            foreach ($head as $c => $v) {
                $x .= self::str(self::colName($c) . $rowNo, (string)$v, self::S_HEAD);
            }
            $x .= '</row>';
        }
        foreach ($s['rows'] as $r) {
            $rowNo++;
            $x .= '<row r="' . $rowNo . '">';
            foreach (array_values((array)$r) as $c => $v) {
                $x .= self::cell(self::colName($c) . $rowNo, $v, $kinds[$c] ?? 'auto', $s['wrap']);
            }
            $x .= '</row>';
        }
        $x .= '</sheetData>';
        $last = self::colName($ncol - 1);
        if ($s['filter'] && $headRow && $rowNo > $headRow) {
            $x .= '<autoFilter ref="A' . $headRow . ':' . $last . $rowNo . '"/>';
        }
        $merges = [];
        foreach ($s['title'] as $i => [$text, $kind]) {
            if ($kind === 'note' && $ncol > 1) {
                $merges[] = 'A' . ($i + 1) . ':' . $last . ($i + 1);
            }
        }
        if ($merges) {
            $x .= '<mergeCells count="' . count($merges) . '">';
            foreach ($merges as $m) {
                $x .= '<mergeCell ref="' . $m . '"/>';
            }
            $x .= '</mergeCells>';
        }
        if ($s['lists'] && $headRow) {
            $x .= '<dataValidations count="' . count($s['lists']) . '">';
            foreach ($s['lists'] as $c => $list) {
                $col = self::colName((int)$c);
                $strict = !empty($list['strict']);
                // a value that is not on the list is warned about, never refused: a name can also be added
                // earlier in the same file, and Import accepts the other spellings of a word
                $x .= '<dataValidation type="list" errorStyle="' . ($strict ? 'warning' : 'information') . '" allowBlank="1" showInputMessage="1" showErrorMessage="' . ($strict ? '1' : '0') . '"'
                    . ' errorTitle="Not on the list" error="' . self::x('Choose one of the values on the list (Yes to keep what you typed).') . '"'
                    . ' sqref="' . $col . ($headRow + 1) . ':' . $col . self::MAX_ROWS . '"><formula1>' . self::x((string)$list['formula']) . '</formula1></dataValidation>';
            }
            $x .= '</dataValidations>';
        }
        $x .= '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
            . '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>';
        if (in_array('text', $kinds, true)) {
            // codes and numbers kept as text are meant to be text: no green triangles on them
            $x .= '<ignoredErrors><ignoredError sqref="A1:' . $last . max(self::MAX_ROWS, $rowNo) . '" numberStoredAsText="1"/></ignoredErrors>';
        }
        return $x . '</worksheet>';
    }

    private static function cell(string $ref, mixed $v, string $kind, bool $wrap): string
    {
        if ($v === null || $v === '') {
            return $kind === 'text' ? '' : '';
        }
        if ($kind === 'text') {
            return self::str($ref, (string)$v, $wrap ? self::S_WRAP : self::S_TEXT);
        }
        if (is_bool($v)) {
            return '<c r="' . $ref . '" t="b"><v>' . ($v ? 1 : 0) . '</v></c>';
        }
        $numStyle = $kind === 'amount' ? self::S_AMOUNT : self::S_NUM;
        if (is_int($v) || is_float($v)) {
            return is_finite((float)$v) ? '<c r="' . $ref . '" s="' . $numStyle . '"><v>' . self::num((float)$v) . '</v></c>' : self::str($ref, (string)$v, 0);
        }
        $s = (string)$v;
        // numbers that are numbers (not codes with a leading zero, not longer than Excel keeps exactly)
        if (in_array($kind, ['auto', 'num', 'amount'], true) && preg_match('/^-?(0|[1-9]\d{0,14})(\.\d{1,10})?$/', $s)) {
            return '<c r="' . $ref . '" s="' . $numStyle . '"><v>' . $s . '</v></c>';
        }
        if (($kind === 'auto' || $kind === 'date') && preg_match('/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$/', $s, $m) && checkdate((int)$m[2], (int)$m[3], (int)$m[1]) && (int)$m[1] >= 1900) {
            $serial = intdiv(gmmktime(0, 0, 0, (int)$m[2], (int)$m[3], (int)$m[1]), 86400) + 25569;   // days since 1899-12-30
            $time = isset($m[4]) ? ((int)$m[4] * 3600 + (int)$m[5] * 60 + (int)($m[6] ?? 0)) / 86400 : 0;
            return '<c r="' . $ref . '" s="' . ($time > 0 ? self::S_DATETIME : self::S_DATE) . '"><v>' . self::num($serial + $time) . '</v></c>';
        }
        return self::str($ref, $s, $wrap ? self::S_WRAP : 0);
    }

    private static function str(string $ref, string $v, int $style): string
    {
        $v = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', '', $v);
        if (!mb_check_encoding($v, 'UTF-8')) {
            $v = mb_convert_encoding($v, 'UTF-8', 'Windows-1252');
        }
        if (mb_strlen($v) > 32000) {
            $v = mb_substr($v, 0, 32000);
        }
        return '<c r="' . $ref . '"' . ($style ? ' s="' . $style . '"' : '') . ' t="inlineStr"><is><t xml:space="preserve">' . self::x($v) . '</t></is></c>';
    }

    private static function num(float $f): string
    {
        $s = rtrim(rtrim(sprintf('%.10F', $f), '0'), '.');
        return $s === '-0' || $s === '' ? '0' : $s;
    }

    private static function x(string $s): string
    {
        return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    /** 0 -> A, 25 -> Z, 26 -> AA */
    public static function colName(int $i): string
    {
        $s = '';
        for ($i++; $i > 0; $i = intdiv($i - 1, 26)) {
            $s = chr(65 + ($i - 1) % 26) . $s;
        }
        return $s;
    }

    private static function sheetName(string $name, array $taken): string
    {
        $name = trim(preg_replace('/[\\\\\/\?\*\[\]:]/', ' ', $name)) ?: 'Sheet';
        $name = mb_substr($name, 0, 31);
        $base = $name;
        for ($n = 2; in_array(mb_strtolower($name), array_map('mb_strtolower', $taken), true); $n++) {
            $name = mb_substr($base, 0, 27) . ' (' . $n . ')';
        }
        return $name;
    }

    /** A zip file of the parts, deflated (zlib only) */
    private static function zip(array $files): string
    {
        $data = '';
        $central = '';
        $time = getdate();
        $dosTime = ($time['hours'] << 11) | ($time['minutes'] << 5) | intdiv($time['seconds'], 2);
        $dosDate = (max(0, $time['year'] - 1980) << 9) | ($time['mon'] << 5) | $time['mday'];
        foreach ($files as $name => $content) {
            $crc = crc32($content);
            $deflated = gzdeflate($content, 6);
            $offset = strlen($data);
            $data .= pack('VvvvvvVVVvv', 0x04034b50, 20, 0x0800, 8, $dosTime, $dosDate, $crc, strlen($deflated), strlen($content), strlen($name), 0) . $name . $deflated;
            $central .= pack('VvvvvvvVVVvvvvvVV', 0x02014b50, 20, 20, 0x0800, 8, $dosTime, $dosDate, $crc, strlen($deflated), strlen($content), strlen($name), 0, 0, 0, 0, 0, $offset) . $name;
        }
        return $data . $central . pack('VvvvvVVv', 0x06054b50, 0, 0, count($files), count($files), strlen($central), strlen($data), 0);
    }

    // ================================================================== reading

    /** True when the bytes are a zip (an .xlsx); an old .xls starts with D0 CF 11 E0 */
    public static function isXlsx(string $bytes): bool
    {
        return str_starts_with($bytes, "PK\x03\x04");
    }

    public static function isOldXls(string $bytes): bool
    {
        return str_starts_with($bytes, "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1");
    }

    /**
     * The sheets of a workbook: [['name' => ..., 'rows' => [rowNumber => [colIndex => text]]], ...] in the
     * order of the tabs, hidden sheets left out. Every value comes back as the text it shows as: a date as
     * 2026-09-30 (with the time when it has one), a number without Excel's rounding noise, TRUE / FALSE.
     */
    public static function sheets(string $bytes): array
    {
        if (!class_exists('XMLReader') || !function_exists('gzinflate')) {
            fail('This server cannot read Excel workbooks (the PHP XML or zlib extension is off). Save the sheet as CSV and choose it again.');
        }
        $zip = self::unzip($bytes);
        $wbXml = $zip['xl/workbook.xml'] ?? null;
        if ($wbXml === null) {
            fail('The file is not an Excel workbook that can be read. In Excel, save it as Excel Workbook (.xlsx) or CSV and choose it again.');
        }
        $wb = self::xml($wbXml);
        if (!$wb) {
            fail('The file is not an Excel workbook that can be read. In Excel, save it as Excel Workbook (.xlsx) or CSV and choose it again.');
        }
        $date1904 = false;
        if ($wb && isset($wb->workbookPr)) {
            $p = (string)($wb->workbookPr->attributes()['date1904'] ?? '');
            $date1904 = $p === '1' || strtolower($p) === 'true';
        }
        $targets = [];
        if (isset($zip['xl/_rels/workbook.xml.rels']) && ($rels = self::xml($zip['xl/_rels/workbook.xml.rels']))) {
            foreach ($rels->Relationship as $r) {
                $t = (string)$r['Target'];
                $t = str_starts_with($t, '/') ? ltrim($t, '/') : 'xl/' . $t;
                $targets[(string)$r['Id']] = self::canonical(self::normPath($t));
            }
        }
        $shared = isset($zip['xl/sharedstrings.xml']) ? self::sharedStrings($zip['xl/sharedstrings.xml']) : [];
        $dateStyles = isset($zip['xl/styles.xml']) ? self::dateStyles($zip['xl/styles.xml']) : [];

        $out = [];
        $i = 0;
        foreach ($wb->sheets->sheet ?? [] as $sh) {
            $i++;
            $state = (string)($sh['state'] ?? '');
            $rid = (string)($sh->attributes('http://schemas.openxmlformats.org/officeDocument/2006/relationships')['id'] ?? '');
            $path = $targets[$rid] ?? 'xl/worksheets/sheet' . $i . '.xml';
            if ($state === 'hidden' || $state === 'veryHidden' || !isset($zip[$path])) {
                continue;
            }
            $out[] = ['name' => (string)$sh['name'], 'rows' => self::sheetRows($zip[$path], $shared, $dateStyles, $date1904)];
        }
        if (!$out) {
            fail('The workbook has no sheet that can be read.');
        }
        return $out;
    }

    private static function xml(string $s): ?SimpleXMLElement
    {
        $prev = libxml_use_internal_errors(true);
        $x = simplexml_load_string($s, 'SimpleXMLElement', LIBXML_NONET | LIBXML_COMPACT);
        libxml_clear_errors();
        libxml_use_internal_errors($prev);
        return $x === false ? null : $x;
    }

    private static function normPath(string $p): string
    {
        $out = [];
        foreach (explode('/', $p) as $part) {
            if ($part === '..') {
                array_pop($out);
            } elseif ($part !== '.' && $part !== '') {
                $out[] = $part;
            }
        }
        return implode('/', $out);
    }

    private static function sharedStrings(string $xml): array
    {
        $out = [];
        $r = new XMLReader();
        $r->XML($xml, 'UTF-8', LIBXML_NONET | LIBXML_COMPACT);
        $cur = null;
        $skip = 0;   // inside a phonetic run (<rPh>), which is not part of the text
        while (@$r->read()) {
            if ($r->nodeType === XMLReader::ELEMENT) {
                if ($r->localName === 'si') {
                    $cur = '';
                    if ($r->isEmptyElement) {
                        $out[] = '';
                        $cur = null;
                    }
                } elseif ($r->localName === 'rPh' && !$r->isEmptyElement) {
                    $skip++;
                } elseif ($r->localName === 't' && $cur !== null && !$skip && !$r->isEmptyElement) {
                    $cur .= $r->readString();
                }
            } elseif ($r->nodeType === XMLReader::END_ELEMENT) {
                if ($r->localName === 'rPh') {
                    $skip = max(0, $skip - 1);
                } elseif ($r->localName === 'si' && $cur !== null) {
                    $out[] = $cur;
                    $cur = null;
                }
            }
        }
        $r->close();
        return $out;
    }

    /** The cell styles (index in cellXfs) whose number format shows a date or a time: style => 'date' | 'datetime' | 'time' */
    private static function dateStyles(string $xml): array
    {
        $x = self::xml($xml);
        if (!$x) {
            return [];
        }
        $custom = [];
        foreach ($x->numFmts->numFmt ?? [] as $f) {
            $custom[(int)$f['numFmtId']] = (string)$f['formatCode'];
        }
        $out = [];
        $i = 0;
        foreach ($x->cellXfs->xf ?? [] as $xf) {
            $id = (int)$xf['numFmtId'];
            $kind = null;
            if (in_array($id, [14, 15, 16, 17, 27, 28, 29, 30, 31, 34, 35, 36, 50, 51, 52, 53, 54, 55, 56, 57, 58], true)) {
                $kind = 'date';
            } elseif ($id === 22) {
                $kind = 'datetime';
            } elseif (in_array($id, [18, 19, 20, 21, 32, 33, 45, 46, 47], true)) {
                $kind = 'time';
            } elseif (isset($custom[$id])) {
                // the letters of a date or time, outside quoted text, [colours] and escaped characters
                $code = strtolower(preg_replace('/"[^"]*"|\[[^\]]*\]|\\\\.|_.|\*./', '', $custom[$id]));
                $hasDate = (bool)preg_match('/[dy]/', $code) || (bool)preg_match('/m{3,}/', $code) || (preg_match('/m/', $code) && !preg_match('/[hs]/', $code) && preg_match('/[dy]/', $code));
                $hasTime = (bool)preg_match('/[hs]/', $code);
                if ($hasDate && $hasTime) {
                    $kind = 'datetime';
                } elseif ($hasDate) {
                    $kind = 'date';
                } elseif ($hasTime && !preg_match('/[#0]/', $code)) {
                    $kind = 'time';
                }
            }
            if ($kind) {
                $out[$i] = $kind;
            }
            $i++;
        }
        return $out;
    }

    private static function sheetRows(string $xml, array $shared, array $dateStyles, bool $date1904): array
    {
        $rows = [];
        $r = new XMLReader();
        $r->XML($xml, 'UTF-8', LIBXML_NONET | LIBXML_COMPACT | LIBXML_PARSEHUGE);
        $rowNo = 0;
        $col = -1;
        $cell = null;
        while (@$r->read()) {
            if ($r->nodeType === XMLReader::ELEMENT) {
                switch ($r->localName) {
                    case 'row':
                        $rowNo = (int)($r->getAttribute('r') ?: $rowNo + 1);
                        $col = -1;
                        break;
                    case 'c':
                        $ref = (string)$r->getAttribute('r');
                        $col = $ref !== '' && preg_match('/^([A-Z]+)/', $ref, $m) ? self::colIndex($m[1]) : $col + 1;
                        $cell = ['t' => (string)$r->getAttribute('t'), 's' => (int)$r->getAttribute('s'), 'v' => null, 'is' => ''];
                        if ($r->isEmptyElement) {
                            $cell = null;
                        }
                        break;
                    case 'v':
                        if ($cell !== null && !$r->isEmptyElement) {
                            $cell['v'] = $r->readString();
                        }
                        break;
                    case 't':
                        if ($cell !== null && $cell['t'] === 'inlineStr' && !$r->isEmptyElement) {
                            $cell['is'] .= $r->readString();
                        }
                        break;
                }
            } elseif ($r->nodeType === XMLReader::END_ELEMENT && $r->localName === 'c' && $cell !== null) {
                $v = self::cellText($cell, $shared, $dateStyles, $date1904);
                if ($v !== '') {
                    $rows[$rowNo][$col] = $v;
                }
                $cell = null;
            }
        }
        $r->close();
        ksort($rows);
        return $rows;
    }

    private static function cellText(array $c, array $shared, array $dateStyles, bool $date1904): string
    {
        $v = $c['v'];
        switch ($c['t']) {
            case 's':
                return $v === null ? '' : (string)($shared[(int)$v] ?? '');
            case 'inlineStr':
                return $c['is'];
            case 'str':
            case 'e':
                return (string)$v;
            case 'b':
                return $v === '1' ? 'TRUE' : ($v === null ? '' : 'FALSE');
            case 'd':
                $v = (string)$v;
                return preg_match('/^(\d{4}-\d{2}-\d{2})T00:00:00/', $v, $m) ? $m[1] : str_replace('T', ' ', substr($v, 0, 16));
        }
        if ($v === null || $v === '') {
            return '';
        }
        if (!is_numeric($v)) {
            return (string)$v;
        }
        $kind = $dateStyles[$c['s']] ?? null;
        if ($kind) {
            $f = (float)$v;
            $days = (int)floor($f);
            $secs = (int)round(($f - $days) * 86400);
            if ($secs >= 86400) {
                [$days, $secs] = [$days + 1, 0];
            }
            if ($kind === 'time') {
                return sprintf('%02d:%02d', intdiv($secs, 3600), intdiv($secs % 3600, 60));
            }
            if ($days < 1 && !$date1904) {
                return sprintf('%02d:%02d', intdiv($secs, 3600), intdiv($secs % 3600, 60));
            }
            // days since 1899-12-30 (1904 workbooks count from 1904-01-01, 1462 days later); 25569 = 1970-01-01
            $out = gmdate('Y-m-d', ($days + ($date1904 ? 1462 : 0) - 25569) * 86400);
            if ($kind === 'datetime' && $secs > 0) {
                $out .= sprintf(' %02d:%02d', intdiv($secs, 3600), intdiv($secs % 3600, 60));
            }
            return $out;
        }
        // a number as it shows, without the floating-point noise Excel writes (0.30000000000000004)
        $f = (float)$v;
        if (abs($f) >= 1e15 || (abs($f) < 1e-10 && $f != 0.0)) {
            return (string)$v;
        }
        if (preg_match('/^-?\d+$/', (string)$v)) {
            return (string)$v;
        }
        $s = rtrim(rtrim(sprintf('%.10F', round($f, 10)), '0'), '.');
        return $s === '-0' ? '0' : $s;
    }

    private static function colIndex(string $letters): int
    {
        $n = 0;
        foreach (str_split($letters) as $ch) {
            $n = $n * 26 + (ord($ch) - 64);
        }
        return $n - 1;
    }

    /** The parts of a zip, by name (stored and deflated entries; what Excel, WPS and LibreOffice write) */
    private static function unzip(string $bytes): array
    {
        $eocd = strrpos(substr($bytes, -66000), "PK\x05\x06");
        if ($eocd === false) {
            fail('The workbook is damaged or not complete. Open it in Excel, save it again and choose it again.');
        }
        $eocd += max(0, strlen($bytes) - 66000);
        $e = unpack('Vsig/vdisk/vcdisk/ventries/vtotal/Vsize/Voffset/vclen', substr($bytes, $eocd, 22));
        $pos = (int)$e['offset'];
        $files = [];
        for ($n = 0; $n < (int)$e['total']; $n++) {
            if (substr($bytes, $pos, 4) !== "PK\x01\x02") {
                break;
            }
            $h = unpack('Vsig/vmade/vneed/vflags/vmethod/vtime/vdate/Vcrc/Vcsize/Vusize/vnlen/vxlen/vclen/vdisk/vint/Vext/Voffset', substr($bytes, $pos, 46));
            $name = substr($bytes, $pos + 46, $h['nlen']);
            $pos += 46 + $h['nlen'] + $h['xlen'] + $h['clen'];
            $lh = unpack('Vsig/vneed/vflags/vmethod/vtime/vdate/Vcrc/Vcsize/Vusize/vnlen/vxlen', substr($bytes, (int)$h['offset'], 30));
            if (($lh['sig'] ?? 0) !== 0x04034b50) {
                continue;
            }
            $start = (int)$h['offset'] + 30 + $lh['nlen'] + $lh['xlen'];
            $raw = substr($bytes, $start, (int)$h['csize']);
            $name = str_replace('\\', '/', ltrim($name, '/'));
            // only the parts that are read; pictures and the rest are skipped
            if (!preg_match('#^(\[Content_Types\]\.xml|xl/workbook\.xml|xl/_rels/workbook\.xml\.rels|xl/sharedStrings\.xml|xl/styles\.xml|xl/worksheets/[^/]+\.xml)$#i', $name)) {
                continue;
            }
            if ((int)$h['method'] === 8) {
                $data = @gzinflate($raw);
            } elseif ((int)$h['method'] === 0) {
                $data = $raw;
            } else {
                $data = false;
            }
            if ($data === false) {
                fail('A part of the workbook could not be unpacked. Open it in Excel, save it again as Excel Workbook (.xlsx) or CSV, and choose it again.');
            }
            $files[$name] = $data;
        }
        // part names are matched without regard to case, the way Excel does
        $lower = [];
        foreach ($files as $k => $v) {
            $lower[self::canonical($k)] = $v;
        }
        return $lower;
    }

    /** "xl/Worksheets/Sheet1.xml" -> "xl/worksheets/sheet1.xml" (the names the workbook refers to are compared the same way) */
    private static function canonical(string $name): string
    {
        return $name === '[Content_Types].xml' ? $name : strtolower($name);
    }
}
