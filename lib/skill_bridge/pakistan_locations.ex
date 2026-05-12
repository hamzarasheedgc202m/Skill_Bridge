defmodule SkillBridge.PakistanLocations do
  @moduledoc "Pakistan provinces, districts, tehsils and major cities."

  @data %{
    "Punjab" => %{
      "Lahore" => %{
        tehsils: ["Lahore City", "Shalimar", "Raiwind", "Cantonment"],
        cities: ["Lahore", "Raiwind", "Kot Radha Kishan"]
      },
      "Faisalabad" => %{
        tehsils: ["Faisalabad City", "Chak Jhumra", "Tandlianwala", "Samundri", "Jaranwala"],
        cities: ["Faisalabad", "Jaranwala", "Samundri"]
      },
      "Rawalpindi" => %{
        tehsils: ["Rawalpindi", "Murree", "Kahuta", "Gujar Khan", "Taxila"],
        cities: ["Rawalpindi", "Taxila", "Wah Cantt", "Murree"]
      },
      "Gujranwala" => %{
        tehsils: ["Gujranwala City", "Kamoke", "Wazirabad", "Nowshera Virkan"],
        cities: ["Gujranwala", "Wazirabad", "Kamoke"]
      },
      "Multan" => %{
        tehsils: ["Multan City", "Shujaabad", "Jalalpur Pirwala", "Shujabad"],
        cities: ["Multan", "Shujabad", "Jalalpur Pirwala"]
      },
      "Bahawalpur" => %{
        tehsils: ["Bahawalpur", "Ahmadpur East", "Hasilpur", "Yazman"],
        cities: ["Bahawalpur", "Ahmadpur East", "Hasilpur"]
      },
      "Sargodha" => %{
        tehsils: ["Sargodha", "Sahiwal", "Sillanwali", "Kot Momin"],
        cities: ["Sargodha", "Sahiwal", "Bhalwal"]
      },
      "Sialkot" => %{
        tehsils: ["Sialkot City", "Sambrial", "Daska", "Pasrur"],
        cities: ["Sialkot", "Daska", "Sambrial"]
      },
      "Rahim Yar Khan" => %{
        tehsils: ["Rahim Yar Khan", "Sadiqabad", "Liaquatpur", "Khanpur"],
        cities: ["Rahim Yar Khan", "Sadiqabad", "Khanpur"]
      },
      "Jhang" => %{
        tehsils: ["Jhang", "Chiniot", "Shorkot", "Ahmed Pur Sial"],
        cities: ["Jhang", "Chiniot", "Shorkot"]
      },
      "Sheikhupura" => %{
        tehsils: ["Sheikhupura", "Ferozewala", "Nankana Sahib", "Safdarabad"],
        cities: ["Sheikhupura", "Nankana Sahib", "Muridke"]
      },
      "Okara" => %{
        tehsils: ["Okara", "Renala Khurd", "Deepalpur"],
        cities: ["Okara", "Renala Khurd", "Deepalpur"]
      },
      "Kasur" => %{
        tehsils: ["Kasur", "Chunian", "Pattoki"],
        cities: ["Kasur", "Pattoki", "Chunian"]
      },
      "Attock" => %{
        tehsils: ["Attock", "Hazro", "Fateh Jang", "Pindigheb"],
        cities: ["Attock", "Hazro", "Fateh Jang"]
      },
      "Khanewal" => %{
        tehsils: ["Khanewal", "Mian Channu", "Kabir Wala", "Tulamba"],
        cities: ["Khanewal", "Mian Channu", "Kabir Wala"]
      },
      "Hafizabad" => %{
        tehsils: ["Hafizabad", "Pindi Bhattian"],
        cities: ["Hafizabad", "Pindi Bhattian"]
      },
      "Chakwal" => %{
        tehsils: ["Chakwal", "Choa Saidan Shah", "Talagang"],
        cities: ["Chakwal", "Talagang"]
      },
      "Bahawalnagar" => %{
        tehsils: ["Bahawalnagar", "Haroonabad", "Chishtian", "Fortabbas"],
        cities: ["Bahawalnagar", "Haroonabad", "Chishtian"]
      },
      "Vehari" => %{
        tehsils: ["Vehari", "Burewala", "Mailsi"],
        cities: ["Vehari", "Burewala", "Mailsi"]
      },
      "Muzaffargarh" => %{
        tehsils: ["Muzaffargarh", "Kot Addu", "Alipur", "Jatoi"],
        cities: ["Muzaffargarh", "Kot Addu", "Alipur"]
      },
      "Lodhran" => %{
        tehsils: ["Lodhran", "Dunyapur", "Kehror Pacca"],
        cities: ["Lodhran", "Dunyapur"]
      },
      "Pakpattan" => %{tehsils: ["Pakpattan", "Arifwala"], cities: ["Pakpattan", "Arifwala"]},
      "Nankana Sahib" => %{
        tehsils: ["Nankana Sahib", "Safdarabad", "Sangla Hill"],
        cities: ["Nankana Sahib", "Sangla Hill"]
      },
      "Narowal" => %{
        tehsils: ["Narowal", "Zafarwal", "Shakargarh"],
        cities: ["Narowal", "Shakargarh"]
      },
      "Mandi Bahauddin" => %{
        tehsils: ["Mandi Bahauddin", "Malikwal", "Phalia"],
        cities: ["Mandi Bahauddin", "Phalia"]
      },
      "Toba Tek Singh" => %{
        tehsils: ["Toba Tek Singh", "Gojra", "Kamalia", "Pir Mahal"],
        cities: ["Toba Tek Singh", "Gojra", "Kamalia"]
      },
      "Layyah" => %{
        tehsils: ["Layyah", "Choubara", "Karor Lal Esan"],
        cities: ["Layyah", "Choubara"]
      },
      "Bhakkar" => %{
        tehsils: ["Bhakkar", "Mankera", "Kalur Kot", "Darya Khan"],
        cities: ["Bhakkar", "Darya Khan"]
      },
      "Khushab" => %{
        tehsils: ["Khushab", "Noorpur Thal", "Quaidabad"],
        cities: ["Khushab", "Jauharabad"]
      },
      "Mianwali" => %{
        tehsils: ["Mianwali", "Isa Khel", "Piplan"],
        cities: ["Mianwali", "Isa Khel"]
      },
      "Chiniot" => %{tehsils: ["Chiniot", "Bhawana", "Lalian"], cities: ["Chiniot", "Bhawana"]}
    },
    "Sindh" => %{
      "Karachi" => %{
        tehsils: [
          "Karachi East",
          "Karachi West",
          "Karachi Central",
          "Karachi South",
          "Malir",
          "Korangi"
        ],
        cities: ["Karachi", "Malir", "Korangi", "Landhi"]
      },
      "Hyderabad" => %{
        tehsils: ["Hyderabad City", "Latifabad", "Qasimabad", "Hyderabad Rural"],
        cities: ["Hyderabad", "Latifabad", "Qasimabad"]
      },
      "Sukkur" => %{tehsils: ["Sukkur", "Rohri", "Saleh Pat"], cities: ["Sukkur", "Rohri"]},
      "Larkana" => %{tehsils: ["Larkana", "Kambar", "Ratodero"], cities: ["Larkana", "Ratodero"]},
      "Nawabshah" => %{
        tehsils: ["Nawabshah", "Sakrand", "Qazi Ahmed"],
        cities: ["Nawabshah", "Sakrand"]
      },
      "Mirpurkhas" => %{
        tehsils: ["Mirpurkhas", "Digri", "Jhuddo"],
        cities: ["Mirpurkhas", "Digri"]
      },
      "Khairpur" => %{tehsils: ["Khairpur", "Gambat", "Kingri"], cities: ["Khairpur", "Gambat"]},
      "Jacobabad" => %{
        tehsils: ["Jacobabad", "Thul", "Garhi Khairo"],
        cities: ["Jacobabad", "Thul"]
      },
      "Dadu" => %{
        tehsils: ["Dadu", "Johi", "Mehar", "Khairpur Nathan Shah"],
        cities: ["Dadu", "Johi"]
      },
      "Badin" => %{
        tehsils: ["Badin", "Tando Bago", "Matli", "Golarchi"],
        cities: ["Badin", "Matli"]
      },
      "Sanghar" => %{
        tehsils: ["Sanghar", "Shahdadpur", "Sinjhoro"],
        cities: ["Sanghar", "Shahdadpur"]
      },
      "Tharparkar" => %{
        tehsils: ["Mithi", "Islamkot", "Diplo", "Nagarparkar"],
        cities: ["Mithi", "Islamkot"]
      },
      "Umerkot" => %{tehsils: ["Umerkot", "Kunri", "Samaro"], cities: ["Umerkot", "Kunri"]},
      "Shikarpur" => %{tehsils: ["Shikarpur", "Garhi Yasin", "Lakhi"], cities: ["Shikarpur"]},
      "Ghotki" => %{tehsils: ["Ghotki", "Mirpur Mathelo", "Ubauro"], cities: ["Ghotki", "Ubauro"]},
      "Thatta" => %{tehsils: ["Thatta", "Sujawal", "Mirpur Sakro"], cities: ["Thatta", "Sujawal"]},
      "Matiari" => %{tehsils: ["Matiari", "Hala", "Saeedabad"], cities: ["Matiari", "Hala"]},
      "Tando Allahyar" => %{
        tehsils: ["Tando Allahyar", "Tando Ghulam Ali", "Chamber"],
        cities: ["Tando Allahyar"]
      },
      "Kashmore" => %{
        tehsils: ["Kashmore", "Kandhkot", "Tangwani"],
        cities: ["Kashmore", "Kandhkot"]
      }
    },
    "Khyber Pakhtunkhwa" => %{
      "Peshawar" => %{
        tehsils: ["Peshawar City", "Peshawar Cantonment", "Chamkani", "Mattani"],
        cities: ["Peshawar", "Hayatabad", "Warsak"]
      },
      "Mardan" => %{
        tehsils: ["Mardan", "Takht Bhai", "Katlang"],
        cities: ["Mardan", "Takht Bhai"]
      },
      "Swat" => %{
        tehsils: ["Saidu Sharif", "Matta", "Kabal", "Babuzai", "Khwazakhela"],
        cities: ["Mingora", "Saidu Sharif", "Matta"]
      },
      "Abbottabad" => %{
        tehsils: ["Abbottabad", "Havelian", "Lora"],
        cities: ["Abbottabad", "Havelian"]
      },
      "Mansehra" => %{tehsils: ["Mansehra", "Balakot", "Oghi"], cities: ["Mansehra", "Balakot"]},
      "Charsadda" => %{
        tehsils: ["Charsadda", "Shabqadar", "Tangi"],
        cities: ["Charsadda", "Shabqadar"]
      },
      "Nowshera" => %{tehsils: ["Nowshera", "Pabbi", "Jehangira"], cities: ["Nowshera", "Pabbi"]},
      "Kohat" => %{tehsils: ["Kohat", "Lachi", "Tall"], cities: ["Kohat", "Lachi"]},
      "Bannu" => %{tehsils: ["Bannu", "Domel", "Miryan"], cities: ["Bannu"]},
      "Haripur" => %{tehsils: ["Haripur", "Ghazi", "Khanpur"], cities: ["Haripur", "Ghazi"]},
      "Malakand" => %{tehsils: ["Bat Khela", "Thana", "Dargai"], cities: ["Bat Khela", "Dargai"]},
      "Dir Lower" => %{
        tehsils: ["Timergara", "Balambat", "Chakdara"],
        cities: ["Timergara", "Chakdara"]
      },
      "Dir Upper" => %{tehsils: ["Dir", "Wari", "Sheringal"], cities: ["Dir"]},
      "Chitral" => %{tehsils: ["Chitral", "Mastuj", "Drosh"], cities: ["Chitral"]},
      "Buner" => %{tehsils: ["Daggar", "Totalai", "Mandanr"], cities: ["Daggar"]},
      "Shangla" => %{tehsils: ["Alpuri", "Chakesar", "Puran"], cities: ["Alpuri"]},
      "Battagram" => %{tehsils: ["Battagram", "Allai", "Shergarh"], cities: ["Battagram"]},
      "Tank" => %{tehsils: ["Tank"], cities: ["Tank"]},
      "Lakki Marwat" => %{
        tehsils: ["Lakki", "Serai Naurang", "Naurang"],
        cities: ["Lakki Marwat"]
      },
      "Dera Ismail Khan" => %{
        tehsils: ["Dera Ismail Khan", "Paharpur", "Kulachi"],
        cities: ["Dera Ismail Khan"]
      },
      "Karak" => %{tehsils: ["Karak", "Takht-e-Nasrati", "Banda Daud Shah"], cities: ["Karak"]},
      "Hangu" => %{tehsils: ["Hangu", "Thall"], cities: ["Hangu"]}
    },
    "Balochistan" => %{
      "Quetta" => %{
        tehsils: ["Quetta", "Pishin", "Mastung", "Kuchlak"],
        cities: ["Quetta", "Mastung", "Kuchlak"]
      },
      "Turbat" => %{tehsils: ["Turbat", "Mand", "Dasht"], cities: ["Turbat"]},
      "Khuzdar" => %{tehsils: ["Khuzdar", "Zehri", "Wadh"], cities: ["Khuzdar"]},
      "Sibi" => %{tehsils: ["Sibi", "Sanni", "Lehri"], cities: ["Sibi"]},
      "Loralai" => %{tehsils: ["Loralai", "Bori", "Duki"], cities: ["Loralai"]},
      "Chaman" => %{tehsils: ["Chaman", "Killa Abdullah"], cities: ["Chaman"]},
      "Gwadar" => %{tehsils: ["Gwadar", "Pasni", "Ormara"], cities: ["Gwadar", "Pasni"]},
      "Zhob" => %{tehsils: ["Zhob", "Qamardin Karez", "Sherani"], cities: ["Zhob"]},
      "Panjgur" => %{tehsils: ["Panjgur", "Gichk"], cities: ["Panjgur"]},
      "Lasbela" => %{tehsils: ["Uthal", "Bela", "Winder", "Hub"], cities: ["Hub", "Uthal"]},
      "Kalat" => %{tehsils: ["Kalat", "Mangochar", "Surab"], cities: ["Kalat"]},
      "Mastung" => %{tehsils: ["Mastung", "Dasht", "Kardan"], cities: ["Mastung"]},
      "Nasirabad" => %{
        tehsils: ["Dera Murad Jamali", "Tamboo", "Sohbatpur"],
        cities: ["Dera Murad Jamali"]
      },
      "Jaffarabad" => %{tehsils: ["Usta Mohammad", "Gandakha"], cities: ["Usta Mohammad"]}
    },
    "Islamabad Capital Territory" => %{
      "Islamabad" => %{
        tehsils: ["Islamabad", "Kahuta", "Rawat"],
        cities: ["Islamabad", "Rawat", "Kahuta", "Tarnol"]
      }
    },
    "Azad Kashmir" => %{
      "Muzaffarabad" => %{
        tehsils: ["Muzaffarabad", "Hatian Bala", "Pattika"],
        cities: ["Muzaffarabad"]
      },
      "Mirpur" => %{
        tehsils: ["Mirpur", "Chakswari", "Dudyal"],
        cities: ["Mirpur", "New Mirpur City"]
      },
      "Rawalakot" => %{tehsils: ["Rawalakot", "Abbaspur", "Hajira"], cities: ["Rawalakot"]},
      "Bagh" => %{tehsils: ["Bagh", "Dhirkot"], cities: ["Bagh"]},
      "Kotli" => %{tehsils: ["Kotli", "Sehnsa", "Charhoi"], cities: ["Kotli"]},
      "Bhimber" => %{tehsils: ["Bhimber", "Samahni"], cities: ["Bhimber"]}
    },
    "Gilgit-Baltistan" => %{
      "Gilgit" => %{tehsils: ["Gilgit", "Danyore", "Jutial"], cities: ["Gilgit"]},
      "Skardu" => %{tehsils: ["Skardu", "Shigar", "Roundu"], cities: ["Skardu"]},
      "Hunza" => %{tehsils: ["Karimabad", "Aliabad", "Nagar"], cities: ["Karimabad"]},
      "Ghanche" => %{tehsils: ["Khaplu", "Daghoni"], cities: ["Khaplu"]},
      "Astore" => %{tehsils: ["Astore", "Gorikot"], cities: ["Astore"]},
      "Ghizer" => %{tehsils: ["Gahkuch", "Gupis", "Phander"], cities: ["Gahkuch"]},
      "Diamer" => %{tehsils: ["Chilas", "Darel", "Tangir"], cities: ["Chilas"]}
    }
  }

  def provinces, do: Map.keys(@data) |> Enum.sort()

  def districts(province) when is_binary(province) do
    Map.get(@data, province, %{}) |> Map.keys() |> Enum.sort()
  end

  def districts(_), do: []

  def tehsils(province, district) when is_binary(province) and is_binary(district) do
    @data
    |> Map.get(province, %{})
    |> Map.get(district, %{})
    |> Map.get(:tehsils, [])
    |> Enum.sort()
  end

  def tehsils(_, _), do: []

  def cities(province, district) when is_binary(province) and is_binary(district) do
    @data
    |> Map.get(province, %{})
    |> Map.get(district, %{})
    |> Map.get(:cities, [])
    |> Enum.sort()
  end

  def cities(_, _), do: []

  def all_cities do
    Enum.flat_map(@data, fn {_prov, districts} ->
      Enum.flat_map(districts, fn {_dist, data} ->
        Map.get(data, :cities, [])
      end)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
