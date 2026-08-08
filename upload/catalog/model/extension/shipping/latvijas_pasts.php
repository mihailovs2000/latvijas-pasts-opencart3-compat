<?php
class ModelExtensionShippingLatvijasPasts extends Model {
	private $endpoints = array(
		'LV' => 'https://express.pasts.lv/stationApi/index',
		'LT' => 'https://express.pasts.lv/extStationApi/index',
		'EE' => 'https://express.pasts.lv/extStationApi/index'
	);

	public function getQuote($address) {
		$this->load->language('extension/shipping/latvijas_pasts');

		$country = isset($address['iso_code_2']) ? strtoupper($address['iso_code_2']) : '';
		if (!isset($this->endpoints[$country]) || !$this->isAvailableInGeoZone($address)) {
			return array();
		}

		$terminals = $this->getTerminals($country);
		if (!$terminals) {
			return array();
		}

		$cost_value = str_replace(',', '.', trim((string)$this->config->get('shipping_latvijas_pasts_cost')));
		if ($cost_value === '' || !is_numeric($cost_value) || (float)$cost_value < 0) {
			return array();
		}

		$cost = (float)$cost_value;
		$free_total = str_replace(',', '.', trim((string)$this->config->get('shipping_latvijas_pasts_free_total')));
		if ($free_total !== '' && is_numeric($free_total) && (float)$free_total > 0 && $this->cart->getSubTotal() >= (float)$free_total) {
			$cost = 0.0;
		}

		$tax_class_id = (int)$this->config->get('shipping_latvijas_pasts_tax_class_id');
		$selected_id = isset($this->session->data['latvijas_pasts_terminal_id']) ? (string)$this->session->data['latvijas_pasts_terminal_id'] : '';

		$quote_data = array(
			'terminal' => array(
				'code' => 'latvijas_pasts.terminal',
				'title' => $this->renderSelector($terminals, $selected_id),
				'cost' => $cost,
				'tax_class_id' => $tax_class_id,
				'text' => $this->currency->format($this->tax->calculate($cost, $tax_class_id, $this->config->get('config_tax')), $this->session->data['currency'])
			)
		);

		return array(
			'code' => 'latvijas_pasts',
			'title' => $this->language->get('text_title'),
			'quote' => $quote_data,
			'sort_order' => (int)$this->config->get('shipping_latvijas_pasts_sort_order'),
			'error' => false
		);
	}

	public function findTerminal($country, $terminal_id) {
		$terminal_id = trim((string)$terminal_id);
		if ($terminal_id === '' || strlen($terminal_id) > 64) {
			return false;
		}

		foreach ($this->getTerminals(strtoupper($country)) as $terminal) {
			if (hash_equals((string)$terminal['id'], $terminal_id)) {
				return $terminal;
			}
		}

		return false;
	}

	public function getTerminals($country) {
		$country = strtoupper((string)$country);
		if (!isset($this->endpoints[$country])) {
			return array();
		}

		$cache_file = rtrim(DIR_CACHE, '/\\') . DIRECTORY_SEPARATOR . 'latvijas_pasts_' . strtolower($country) . '.json';
		$cached = $this->readCache($cache_file);
		$ttl = (int)$this->config->get('shipping_latvijas_pasts_cache_ttl');
		if ($ttl < 300 || $ttl > 604800) {
			$ttl = 86400;
		}

		if ($cached && is_file($cache_file) && time() - filemtime($cache_file) < $ttl) {
			return $cached;
		}

		$fresh = $this->fetchJson($this->endpoints[$country]);
		$terminals = $this->normalizeTerminals($fresh, $country);

		if ($terminals) {
			$this->writeCache($cache_file, $terminals);
			return $terminals;
		}

		return $cached;
	}

	private function isAvailableInGeoZone($address) {
		$geo_zone_id = (int)$this->config->get('shipping_latvijas_pasts_geo_zone_id');
		if (!$geo_zone_id) {
			return true;
		}

		$query = $this->db->query("SELECT zone_to_geo_zone_id FROM " . DB_PREFIX . "zone_to_geo_zone WHERE geo_zone_id = '" . $geo_zone_id . "' AND country_id = '" . (int)$address['country_id'] . "' AND (zone_id = '" . (int)$address['zone_id'] . "' OR zone_id = '0') LIMIT 1");
		return (bool)$query->num_rows;
	}

	private function fetchJson($url) {
		$curl = curl_init($url);
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($curl, CURLOPT_FOLLOWLOCATION, false);
		curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, true);
		curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, 2);
		curl_setopt($curl, CURLOPT_CONNECTTIMEOUT, 5);
		curl_setopt($curl, CURLOPT_TIMEOUT, 10);
		curl_setopt($curl, CURLOPT_HTTPHEADER, array('Accept: application/json'));
		curl_setopt($curl, CURLOPT_USERAGENT, 'Latvijas-Pasts-Parcel-Lockers-OpenCart/1.0.0');

		$response = curl_exec($curl);
		$status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);

		if ($response === false || $status < 200 || $status >= 300) {
			return array();
		}

		$data = json_decode($response, true);
		return is_array($data) ? $data : array();
	}

	private function normalizeTerminals($data, $country) {
		$terminals = array();

		foreach ($data as $row) {
			if (!is_array($row) || !isset($row['id'])) {
				continue;
			}

			if ($country !== 'LV' && isset($row['country']) && strtoupper($row['country']) !== $country) {
				continue;
			}

			$id = trim((string)$row['id']);
			if ($id === '' || strlen($id) > 64 || !preg_match('/^[A-Za-z0-9_-]+$/', $id)) {
				continue;
			}

			$name = '';
			foreach (array('name', 'title', 'label') as $key) {
				if (!empty($row[$key])) {
					$name = trim((string)$row[$key]);
					break;
				}
			}

			$address = !empty($row['address']) ? trim((string)$row['address']) : '';
			if ($name === '' && $address === '') {
				continue;
			}

			$label = $name;
			if ($address !== '' && stripos($name, $address) === false) {
				$label .= ($label !== '' ? ' — ' : '') . $address;
			}

			$terminals[] = array('id' => $id, 'label' => $label);
		}

		usort($terminals, function ($a, $b) {
			return strnatcasecmp($a['label'], $b['label']);
		});

		return $terminals;
	}

	private function readCache($file) {
		if (!is_file($file)) {
			return array();
		}

		$content = file_get_contents($file);
		if ($content === false) {
			return array();
		}

		$data = json_decode($content, true);
		return is_array($data) ? $data : array();
	}

	private function writeCache($file, $data) {
		$json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
		if ($json === false) {
			return;
		}

		$temp = $file . '.' . uniqid('tmp', true);
		if (file_put_contents($temp, $json, LOCK_EX) !== false) {
			@rename($temp, $file);
		} else {
			@unlink($temp);
		}
	}

	private function renderSelector($terminals, $selected_id) {
		$search_id = 'latvijas-pasts-search';
		$select_id = 'latvijas-pasts-terminal';
		$html = '<div class="latvijas-pasts-selector">';
		$html .= '<span class="latvijas-pasts-method">' . $this->escape($this->language->get('text_method')) . '</span>';
		$html .= '<input type="search" id="' . $search_id . '" class="form-control" autocomplete="off" placeholder="' . $this->escape($this->language->get('text_search')) . '">';
		$html .= '<select name="latvijas_pasts_terminal" id="' . $select_id . '" class="form-control">';
		$html .= '<option value="">' . $this->escape($this->language->get('text_select')) . '</option>';

		foreach ($terminals as $terminal) {
			$selected = hash_equals((string)$terminal['id'], (string)$selected_id) ? ' selected="selected"' : '';
			$html .= '<option value="' . $this->escape($terminal['id']) . '"' . $selected . '>' . $this->escape($terminal['label']) . '</option>';
		}

		$html .= '</select></div>';
		$html .= '<script>(function(){var q=document.getElementById("' . $search_id . '");var s=document.getElementById("' . $select_id . '");if(!q||!s||s.getAttribute("data-ready")){return;}s.setAttribute("data-ready","1");var o=Array.prototype.slice.call(s.options,1);q.addEventListener("input",function(){var v=this.value.toLocaleLowerCase();o.forEach(function(x){x.hidden=v!==""&&x.text.toLocaleLowerCase().indexOf(v)===-1;});});s.addEventListener("change",function(){var r=document.querySelector("input[name=shipping_method][value=\\"latvijas_pasts.terminal\\"]");if(r){r.checked=true;}});})();</script>';

		return $html;
	}

	private function escape($value) {
		return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
	}
}
