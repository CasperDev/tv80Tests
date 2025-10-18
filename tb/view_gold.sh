	# --- Otwórz GTKWave, jeśli proszono ---
	vcd_file=fuse_gold.vcd
	gtkw_file=fuse_gold.gtkw 
    
	if [ -f "$vcd_file" ]; then
		echo "📈 Opening GTKWave for test..."
		if [ -f "$gtkw_file" ]; then
			(nohup gtkwave --rcvar 'fontname_signals Monospace 13' --rcvar 'fontname_waves Monospace 13' "${vcd_file}" "${gtkw_file}" >/dev/null 2>&1 & disown)
		else
			(nohup gtkwave --rcvar 'fontname_signals Monospace 13' --rcvar 'fontname_waves Monospace 13' "${vcd_file}" >/dev/null 2>&1 & disown)
		fi
	else
		echo "⚠️  VCD file not found: $vcd_file"
	fi
