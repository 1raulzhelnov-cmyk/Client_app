import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class S {
  S(this.locale);

  final Locale locale;

  static S? _current;

  static S get current {
    final instance = _current;
    if (instance == null) {
      throw StateError(
        'S has not been initialized. Call S.load before accessing.',
      );
    }
    return instance;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
  ];

  static final Map<String, Map<String, String>> _localizedValues =
      <String, Map<String, String>>{
    'en': _enValues,
    'ru': _ruValues,
  };

  static Future<S> load(Locale locale) {
    final localeName = Intl.canonicalizedLocale(
      locale.languageCode,
    );
    final values =
        _localizedValues[localeName] ?? _localizedValues[S._fallbackLocale]!;
    _current = S(Locale(localeName)).._cache = values;
    return SynchronousFuture<S>(_current!);
  }

  static const String _fallbackLocale = 'ru';

  static S of(BuildContext context) {
    final instance = Localizations.of<S>(context, S);
    if (instance == null) {
      throw StateError('S.of(context) called before S.load');
    }
    return instance;
  }

  late Map<String, String> _cache;

  String _t(String key) {
    final value = _cache[key];
    if (value == null) {
      debugPrint('Missing localization key: $key for locale ${locale.languageCode}');
      return key;
    }
    return value;
  }

  // Common
  String get appTitle => _t('appTitle');
  String get loading => _t('loading');
  String get retry => _t('retry');
  String get ok => _t('ok');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get confirm => _t('confirm');
  String get errorGeneric => _t('errorGeneric');
  String get successGeneric => _t('successGeneric');
  String get requiredField => _t('requiredField');
  String get invalidEmail => _t('invalidEmail');
  String get invalidPassword => _t('invalidPassword');
  String get invalidPhone => _t('invalidPhone');

  // Auth
  String get loginTitle => _t('loginTitle');
  String get loginSubtitle => _t('loginSubtitle');
  String get loginButton => _t('loginButton');
  String get emailField => _t('emailField');
  String get passwordField => _t('passwordField');
  String get forgotPassword => _t('forgotPassword');
  String get registerPrompt => _t('registerPrompt');
  String get registerTitle => _t('registerTitle');
  String get registerButton => _t('registerButton');
  String get confirmPasswordField => _t('confirmPasswordField');
  String get phoneField => _t('phoneField');
  String get orDivider => _t('orDivider');
  String get googleSignIn => _t('googleSignIn');
  String get appleSignIn => _t('appleSignIn');
  String get logoutButton => _t('logoutButton');
  String get otpTitle => _t('otpTitle');
  String get otpSubtitle => _t('otpSubtitle');
  String get verifyCode => _t('verifyCode');
  String get resendCode => _t('resendCode');
  String get sendCode => _t('sendCode');
  String get otpSent => _t('otpSent');
  String get invalidOtp => _t('invalidOtp');
  String get passwordMismatch => _t('passwordMismatch');

  // Profile
  String get profileTitle => _t('profileTitle');
  String get editProfileTitle => _t('editProfileTitle');
  String get editProfileButton => _t('editProfileButton');
  String get viewProfileButton => _t('viewProfileButton');
  String get fullNameField => _t('fullNameField');
  String get saveChanges => _t('saveChanges');
  String get changePhoto => _t('changePhoto');
  String get photoSourceGallery => _t('photoSourceGallery');
  String get photoSourceCamera => _t('photoSourceCamera');
  String get deleteAccount => _t('deleteAccount');
  String get accountUpdated => _t('accountUpdated');
  String get photoUpdated => _t('photoUpdated');
  String get accountDeleted => _t('accountDeleted');
  String get confirmDeletionTitle => _t('confirmDeletionTitle');
  String get confirmDeletionMessage => _t('confirmDeletionMessage');

  // Addresses
  String get addressesTitle => _t('addressesTitle');
  String get addAddress => _t('addAddress');
  String get editAddress => _t('editAddress');
  String get deleteAddress => _t('deleteAddress');
  String get addressInstructions => _t('addressInstructions');
  String get searchAddress => _t('searchAddress');
  String get selectOnMap => _t('selectOnMap');
  String get primaryAddress => _t('primaryAddress');
  String get addressSaved => _t('addressSaved');
  String get addressDeleted => _t('addressDeleted');

  // Navigation / Home
  String get home => _t('home');
  String get cart => _t('cart');
  String get orders => _t('orders');
  String get profile => _t('profile');
  String get food => _t('food');
  String get flowers => _t('flowers');
  String get searchPlaceholder => _t('searchPlaceholder');
  String get filterTitle => _t('filterTitle');
  String get sortTitle => _t('sortTitle');
  String get ratingFilter => _t('ratingFilter');
  String get priceFilter => _t('priceFilter');
  String get distanceFilter => _t('distanceFilter');
  String get cuisineFilter => _t('cuisineFilter');
  String get applyFilters => _t('applyFilters');
  String get clearFilters => _t('clearFilters');
  String get noVenuesFound => _t('noVenuesFound');
  String get cachedVenuesMessage => _t('cachedVenuesMessage');

  // Venue details
  String get overviewTab => _t('overviewTab');
  String get menuTab => _t('menuTab');
  String get catalogTab => _t('catalogTab');
  String get workingHours => _t('workingHours');
  String get contactInfo => _t('contactInfo');
  String get reviews => _t('reviews');
  String get addToCart => _t('addToCart');
  String get customize => _t('customize');
  String get unavailable => _t('unavailable');
  String get seeAll => _t('seeAll');

  // Cart
  String get cartTitle => _t('cartTitle');
  String get emptyCart => _t('emptyCart');
  String get goToHome => _t('goToHome');
  String get total => _t('total');
  String get checkout => _t('checkout');
  String get removeItem => _t('removeItem');
  String get increaseQuantity => _t('increaseQuantity');
  String get decreaseQuantity => _t('decreaseQuantity');
  String get orderSummary => _t('orderSummary');
  String get itemsLabel => _t('itemsLabel');

  // Customization
  String get chooseSize => _t('chooseSize');
  String get additionalOptions => _t('additionalOptions');
  String get specialInstructions => _t('specialInstructions');
  String get addButton => _t('addButton');

  // Checkout / Payment
  String get checkoutTitle => _t('checkoutTitle');
  String get selectAddress => _t('selectAddress');
  String get termsAcceptance => _t('termsAcceptance');
  String get placeOrder => _t('placeOrder');
  String get etaLabel => _t('etaLabel');
  String get acceptTermsError => _t('acceptTermsError');
  String get cashPayment => _t('cashPayment');
  String get cardPayment => _t('cardPayment');
  String get paymentMethod => _t('paymentMethod');
  String get savedCards => _t('savedCards');
  String get addNewCard => _t('addNewCard');
  String get saveCard => _t('saveCard');
  String get payNow => _t('payNow');
  String get cashInstructions => _t('cashInstructions');
  String get cashFeeApplied => _t('cashFeeApplied');
  String get orderPlaced => _t('orderPlaced');

  // Orders
  String get orderStatusTitle => _t('orderStatusTitle');
  String get orderHistoryTitle => _t('orderHistoryTitle');
  String get searchOrders => _t('searchOrders');
  String get downloadReceipt => _t('downloadReceipt');
  String get cancelOrder => _t('cancelOrder');
  String get cancellationReason => _t('cancellationReason');
  String get confirmCancellation => _t('confirmCancellation');
  String get refundInfo => _t('refundInfo');
  String get rateOrder => _t('rateOrder');
  String get leaveReview => _t('leaveReview');
  String get submitReview => _t('submitReview');
  String get addPhotos => _t('addPhotos');
  String get reviewThanks => _t('reviewThanks');

  // Status labels
  String get statusPlaced => _t('statusPlaced');
  String get statusConfirmed => _t('statusConfirmed');
  String get statusPreparing => _t('statusPreparing');
  String get statusTransit => _t('statusTransit');
  String get statusDelivered => _t('statusDelivered');
  String get statusCancelled => _t('statusCancelled');
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ru', 'en'].contains(locale.languageCode);
  }

  @override
  Future<S> load(Locale locale) => S.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<S> old) => false;
}

const Map<String, String> _ruValues = <String, String>{
  'appTitle': 'Eazy Доставка',
  'loading': 'Загрузка...',
  'retry': 'Повторить',
  'ok': 'ОК',
  'cancel': 'Отмена',
  'save': 'Сохранить',
  'delete': 'Удалить',
  'confirm': 'Подтвердить',
  'errorGeneric': 'Произошла ошибка. Попробуйте снова.',
  'successGeneric': 'Успешно выполнено',
  'requiredField': 'Поле обязательно для заполнения',
  'invalidEmail': 'Введите корректный email',
  'invalidPassword': 'Пароль не соответствует требованиям',
  'invalidPhone': 'Неверный номер телефона',
  'loginTitle': 'Добро пожаловать обратно',
  'loginSubtitle': 'Введите данные аккаунта',
  'loginButton': 'Войти',
  'emailField': 'Email',
  'passwordField': 'Пароль',
  'forgotPassword': 'Забыли пароль?',
  'registerPrompt': 'Нет аккаунта? Зарегистрироваться',
  'registerTitle': 'Создать аккаунт',
  'registerButton': 'Зарегистрироваться',
  'confirmPasswordField': 'Подтвердите пароль',
  'phoneField': 'Телефон',
  'orDivider': 'Или продолжить через',
  'googleSignIn': 'Войти через Google',
  'appleSignIn': 'Войти через Apple',
  'logoutButton': 'Выйти',
  'otpTitle': 'Подтвердите номер',
  'otpSubtitle': 'Мы отправили SMS с кодом подтверждения',
  'verifyCode': 'Подтвердить код',
  'resendCode': 'Отправить код снова',
  'sendCode': 'Отправить код',
  'otpSent': 'Код подтверждения отправлен',
  'invalidOtp': 'Неверный код подтверждения',
  'passwordMismatch': 'Пароли не совпадают',
  'profileTitle': 'Профиль',
  'editProfileTitle': 'Редактирование профиля',
  'editProfileButton': 'Редактировать',
  'viewProfileButton': 'Перейти в профиль',
  'fullNameField': 'Полное имя',
  'saveChanges': 'Сохранить изменения',
  'changePhoto': 'Изменить фото',
  'photoSourceGallery': 'Галерея',
  'photoSourceCamera': 'Камера',
  'deleteAccount': 'Удалить аккаунт',
  'accountUpdated': 'Профиль обновлен',
  'photoUpdated': 'Фото обновлено',
  'accountDeleted': 'Аккаунт удалён',
  'confirmDeletionTitle': 'Удалить аккаунт?',
  'confirmDeletionMessage':
      'После удаления аккаунта восстановить данные будет невозможно.',
  'addressesTitle': 'Мои адреса',
  'addAddress': 'Добавить адрес',
  'editAddress': 'Редактировать адрес',
  'deleteAddress': 'Удалить адрес',
  'addressInstructions': 'Инструкции для курьера',
  'searchAddress': 'Поиск адреса',
  'selectOnMap': 'Выбрать на карте',
  'primaryAddress': 'Адрес по умолчанию',
  'addressSaved': 'Адрес сохранён',
  'addressDeleted': 'Адрес удалён',
  'home': 'Главная',
  'cart': 'Корзина',
  'orders': 'Заказы',
  'profile': 'Профиль',
  'food': 'Еда',
  'flowers': 'Цветы',
  'searchPlaceholder': 'Поиск по меню и магазинам',
  'filterTitle': 'Фильтры',
  'sortTitle': 'Сортировка',
  'ratingFilter': 'Рейтинг',
  'priceFilter': 'Цена',
  'distanceFilter': 'Расстояние',
  'cuisineFilter': 'Кухня/повод',
  'applyFilters': 'Применить фильтры',
  'clearFilters': 'Очистить',
  'noVenuesFound': 'Ничего не найдено',
  'cachedVenuesMessage': 'Показаны данные из кеша',
  'overviewTab': 'Обзор',
  'menuTab': 'Меню',
  'catalogTab': 'Каталог',
  'workingHours': 'Часы работы',
  'contactInfo': 'Контакты',
  'reviews': 'Отзывы',
  'addToCart': 'Добавить в корзину',
  'customize': 'Настроить',
  'unavailable': 'Недоступно',
  'seeAll': 'Смотреть все',
  'cartTitle': 'Корзина',
  'emptyCart': 'Корзина пуста',
  'goToHome': 'Перейти на главную',
  'total': 'Итого',
  'checkout': 'Оформить заказ',
  'removeItem': 'Удалить',
  'increaseQuantity': 'Увеличить количество',
  'decreaseQuantity': 'Уменьшить количество',
  'orderSummary': 'Сводка заказа',
  'itemsLabel': 'Товары',
  'chooseSize': 'Выберите размер',
  'additionalOptions': 'Дополнительные опции',
  'specialInstructions': 'Особые инструкции',
  'addButton': 'Добавить',
  'checkoutTitle': 'Оформление заказа',
  'selectAddress': 'Выберите адрес доставки',
  'termsAcceptance': 'Я принимаю условия сервиса',
  'placeOrder': 'Подтвердить заказ',
  'etaLabel': 'Ожидаемое время доставки',
  'acceptTermsError': 'Нужно принять условия сервиса',
  'cashPayment': 'Наличные',
  'cardPayment': 'Банковская карта',
  'paymentMethod': 'Способ оплаты',
  'savedCards': 'Сохранённые карты',
  'addNewCard': 'Добавить новую карту',
  'saveCard': 'Сохранить карту',
  'payNow': 'Оплатить',
  'cashInstructions': 'Инструкции для оплаты наличными',
  'cashFeeApplied': 'Дополнительная комиссия за наличные',
  'orderPlaced': 'Заказ оформлен',
  'orderStatusTitle': 'Статус заказа',
  'orderHistoryTitle': 'История заказов',
  'searchOrders': 'Поиск заказов',
  'downloadReceipt': 'Скачать чек',
  'cancelOrder': 'Отменить заказ',
  'cancellationReason': 'Причина отмены',
  'confirmCancellation': 'Подтвердить отмену',
  'refundInfo': 'Возврат при отмене возможен, если заказ не в пути.',
  'rateOrder': 'Оценить заказ',
  'leaveReview': 'Оставить отзыв',
  'submitReview': 'Отправить отзыв',
  'addPhotos': 'Добавить фото',
  'reviewThanks': 'Спасибо за отзыв!',
  'statusPlaced': 'Создан',
  'statusConfirmed': 'Подтверждён',
  'statusPreparing': 'Готовится',
  'statusTransit': 'В пути',
  'statusDelivered': 'Доставлен',
  'statusCancelled': 'Отменён',
};

const Map<String, String> _enValues = <String, String>{
  'appTitle': 'Eazy Delivery',
  'loading': 'Loading...',
  'retry': 'Retry',
  'ok': 'OK',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'confirm': 'Confirm',
  'errorGeneric': 'Something went wrong. Please try again.',
  'successGeneric': 'Action completed successfully',
  'requiredField': 'This field is required',
  'invalidEmail': 'Enter a valid email address',
  'invalidPassword': 'Password does not meet requirements',
  'invalidPhone': 'Invalid phone number',
  'loginTitle': 'Welcome back',
  'loginSubtitle': 'Enter your account details',
  'loginButton': 'Sign in',
  'emailField': 'Email',
  'passwordField': 'Password',
  'forgotPassword': 'Forgot password?',
  'registerPrompt': 'No account? Register',
  'registerTitle': 'Create account',
  'registerButton': 'Sign up',
  'confirmPasswordField': 'Confirm password',
  'phoneField': 'Phone number',
  'orDivider': 'Or continue with',
  'googleSignIn': 'Sign in with Google',
  'appleSignIn': 'Sign in with Apple',
  'logoutButton': 'Sign out',
  'otpTitle': 'Verify phone',
  'otpSubtitle': 'We sent an SMS with a verification code',
  'verifyCode': 'Verify code',
  'resendCode': 'Resend code',
  'sendCode': 'Send code',
  'otpSent': 'Verification code sent',
  'invalidOtp': 'Invalid verification code',
  'passwordMismatch': 'Passwords do not match',
  'profileTitle': 'Profile',
  'editProfileTitle': 'Edit profile',
  'editProfileButton': 'Edit',
  'viewProfileButton': 'Go to profile',
  'fullNameField': 'Full name',
  'saveChanges': 'Save changes',
  'changePhoto': 'Change photo',
  'photoSourceGallery': 'Gallery',
  'photoSourceCamera': 'Camera',
  'deleteAccount': 'Delete account',
  'accountUpdated': 'Profile updated',
  'photoUpdated': 'Photo updated',
  'accountDeleted': 'Account deleted',
  'confirmDeletionTitle': 'Delete account?',
  'confirmDeletionMessage':
      'After deleting the account your data cannot be restored.',
  'addressesTitle': 'My addresses',
  'addAddress': 'Add address',
  'editAddress': 'Edit address',
  'deleteAddress': 'Delete address',
  'addressInstructions': 'Delivery instructions',
  'searchAddress': 'Search address',
  'selectOnMap': 'Select on map',
  'primaryAddress': 'Default address',
  'addressSaved': 'Address saved',
  'addressDeleted': 'Address deleted',
  'home': 'Home',
  'cart': 'Cart',
  'orders': 'Orders',
  'profile': 'Profile',
  'food': 'Food',
  'flowers': 'Flowers',
  'searchPlaceholder': 'Search menu and stores',
  'filterTitle': 'Filters',
  'sortTitle': 'Sorting',
  'ratingFilter': 'Rating',
  'priceFilter': 'Price',
  'distanceFilter': 'Distance',
  'cuisineFilter': 'Cuisine / occasion',
  'applyFilters': 'Apply filters',
  'clearFilters': 'Clear',
  'noVenuesFound': 'No venues found',
  'cachedVenuesMessage': 'Showing cached data',
  'overviewTab': 'Overview',
  'menuTab': 'Menu',
  'catalogTab': 'Catalog',
  'workingHours': 'Working hours',
  'contactInfo': 'Contacts',
  'reviews': 'Reviews',
  'addToCart': 'Add to cart',
  'customize': 'Customize',
  'unavailable': 'Unavailable',
  'seeAll': 'See all',
  'cartTitle': 'Cart',
  'emptyCart': 'Your cart is empty',
  'goToHome': 'Back to home',
  'total': 'Total',
  'checkout': 'Checkout',
  'removeItem': 'Remove',
  'increaseQuantity': 'Increase quantity',
  'decreaseQuantity': 'Decrease quantity',
  'orderSummary': 'Order summary',
  'itemsLabel': 'Items',
  'chooseSize': 'Choose size',
  'additionalOptions': 'Additional options',
  'specialInstructions': 'Special instructions',
  'addButton': 'Add',
  'checkoutTitle': 'Checkout',
  'selectAddress': 'Select delivery address',
  'termsAcceptance': 'I accept the terms of service',
  'placeOrder': 'Place order',
  'etaLabel': 'Estimated delivery time',
  'acceptTermsError': 'You need to accept the terms',
  'cashPayment': 'Cash',
  'cardPayment': 'Card',
  'paymentMethod': 'Payment method',
  'savedCards': 'Saved cards',
  'addNewCard': 'Add new card',
  'saveCard': 'Save card',
  'payNow': 'Pay now',
  'cashInstructions': 'Instructions for cash payment',
  'cashFeeApplied': 'Additional cash handling fee',
  'orderPlaced': 'Order placed',
  'orderStatusTitle': 'Order status',
  'orderHistoryTitle': 'Order history',
  'searchOrders': 'Search orders',
  'downloadReceipt': 'Download receipt',
  'cancelOrder': 'Cancel order',
  'cancellationReason': 'Cancellation reason',
  'confirmCancellation': 'Confirm cancellation',
  'refundInfo': 'Refund available if the order has not left yet.',
  'rateOrder': 'Rate order',
  'leaveReview': 'Leave a review',
  'submitReview': 'Submit review',
  'addPhotos': 'Add photos',
  'reviewThanks': 'Thanks for your feedback!',
  'statusPlaced': 'Placed',
  'statusConfirmed': 'Confirmed',
  'statusPreparing': 'Preparing',
  'statusTransit': 'In transit',
  'statusDelivered': 'Delivered',
  'statusCancelled': 'Cancelled',
};
