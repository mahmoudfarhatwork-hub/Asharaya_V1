#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  📊 تقرير مشروع Asharaya — $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📁 [1] معلومات عامة"
echo "─────────────────────────────────────────────────────────"
echo "المسار: $(pwd)"
echo "الحجم: $(du -sh . 2>/dev/null | cut -f1)"
echo "عدد الملفات: $(find . -type f -not -path './.git/*' 2>/dev/null | wc -l)"
echo ""
echo "🎮 [2] ملفات Godot"
echo "─────────────────────────────────────────────────────────"
echo "ملفات .gd:     $(find . -name '*.gd' -not -path './.git/*' 2>/dev/null | wc -l)"
echo "ملفات .tscn:   $(find . -name '*.tscn' -not -path './.git/*' 2>/dev/null | wc -l)"
echo "ملفات .tres:   $(find . -name '*.tres' -not -path './.git/*' 2>/dev/null | wc -l)"
echo ""
echo "📝 [3] أسطر الكود"
echo "─────────────────────────────────────────────────────────"
echo "إجمالي .gd (بدون addons): $(find . -name '*.gd' -not -path '*/addons/*' -not -path './.git/*' -exec cat {} \; 2>/dev/null | wc -l) سطر"
echo "ملفات scripts/:            $(find ./godot_project_FINAL/scripts -name '*.gd' -exec cat {} \; 2>/dev/null | wc -l) سطر"
echo ""
echo "🎨 [4] الأصول"
echo "─────────────────────────────────────────────────────────"
if [ -d ./godot_project_FINAL/assets ]; then
  echo "حجم assets:      $(du -sh ./godot_project_FINAL/assets 2>/dev/null | cut -f1)"
  echo "موديلات:         $(find ./godot_project_FINAL/assets \( -name '*.glb' -o -name '*.gltf' -o -name '*.fbx' \) 2>/dev/null | wc -l)"
  echo "تكسترات:         $(find ./godot_project_FINAL/assets -name '*.png' 2>/dev/null | wc -l)"
  echo "أصوات:           $(find ./godot_project_FINAL/assets \( -name '*.ogg' -o -name '*.wav' \) 2>/dev/null | wc -l)"
fi
echo ""
echo "💻 [5] أكبر 10 ملفات كود"
echo "─────────────────────────────────────────────────────────"
find . -name "*.gd" -not -path './.git/*' -not -path '*/addons/*' -exec wc -l {} \; 2>/dev/null | sort -rn | head -10
echo ""
echo "📌 [6] Git"
echo "─────────────────────────────────────────────────────────"
if [ -d .git ]; then
  echo "الفرع:      $(git branch --show-current 2>/dev/null)"
  echo "آخر commit: $(git log -1 --pretty=format:'%h - %s' 2>/dev/null)"
  echo "commits:    $(git rev-list --count HEAD 2>/dev/null)"
else
  echo "مفيش Git"
fi
echo ""
echo "🔍 [7] أخطاء gdlint (الأصلي)"
echo "─────────────────────────────────────────────────────────"
if [ -f gdlint_report.txt ]; then
  echo "عدد الأسطر: $(wc -l < gdlint_report.txt)"
  grep -oE '\(([a-z-]+)\)' gdlint_report.txt 2>/dev/null | sort | uniq -c | sort -rn
else
  echo "مفيش gdlint_report.txt"
fi
echo ""
echo "🔍 [8] أخطاء gdlint (بعد .gdlintrc)"
echo "─────────────────────────────────────────────────────────"
if [ -f gdlint_clean.txt ]; then
  echo "عدد الأسطر: $(wc -l < gdlint_clean.txt)"
  grep -oE '\(([a-z-]+)\)' gdlint_clean.txt 2>/dev/null | sort | uniq -c | sort -rn
else
  echo "مفيش gdlint_clean.txt"
fi
echo ""
echo "📂 [9] هيكل المشروع"
echo "─────────────────────────────────────────────────────────"
ls -d */ 2>/dev/null
echo ""
echo "🎬 [10] مشاهد Godot"
echo "─────────────────────────────────────────────────────────"
find ./godot_project_FINAL -name "*.tscn" -not -path '*/addons/*' 2>/dev/null | head -20
echo ""
echo "📄 [11] ملفات التوثيق"
echo "─────────────────────────────────────────────────────────"
find . -maxdepth 2 -name "*.md" -not -path './.git/*' -not -path '*/addons/*' 2>/dev/null
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ التقرير انتهى"
echo "═══════════════════════════════════════════════════════════"
